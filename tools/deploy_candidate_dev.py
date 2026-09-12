"""Install verified candidate game/API images into an idle development environment."""
import argparse
import json
import os
import hashlib
from pathlib import Path
import subprocess
import time
import httpx
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ["docker", "compose", "--env-file", "artifacts/duo-dev.env", "-f", "compose.duo-dev.yaml"]
OVERRIDE = ROOT / "artifacts/duo-candidate.override.json"


def output(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def redis(*args):
    return output(COMPOSE + ["exec", "-T", "redis", "redis-cli", "--raw", *args])


def room():
    raw = redis("GET", "im:rooms:room:room-27031")
    return json.loads(raw) if raw else None


def wait_expired():
    deadline = time.monotonic() + 20
    while room() is not None:
        assert time.monotonic() < deadline, "Old room lease did not expire"
        time.sleep(0.5)


def fingerprints():
    sql = "SELECT json_build_object(" + ",".join(
        f"'{table}',(SELECT md5(coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'')) FROM {table} t)"
        for table in ["users", "matches", "results"]) + ")"
    return json.loads(output(COMPOSE + ["exec", "-T", "postgres", "psql", "-U", "iron", "-d", "iron_duo", "-At", "-c", sql]))


def select_images(game_id, api_id, update_api):
    OVERRIDE.write_text(json.dumps({"services": {
        service: {"image": image, "pull_policy": "never"}
        for service, image in {"api": api_id, "game": game_id}.items()}}, indent=2) + "\n")
    command = COMPOSE + ["-f", str(OVERRIDE)]
    if update_api:
        subprocess.run(command + ["up", "-d", "--no-deps", "--no-build", "--wait", "--wait-timeout", "60", "api"],
                       cwd=ROOT, check=True, timeout=90)
    subprocess.run(command + ["up", "-d", "--no-deps", "--no-build", "game"],
                   cwd=ROOT, check=True, timeout=60)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--with-api", action="store_true", help="Also install the candidate backend after backing up development data")
    options = parser.parse_args()
    directory = options.candidate_dir.resolve()
    _, candidate = candidate_command(directory)
    image = json.loads((directory / "server-image.json").read_text())
    assert image["status"] == "passed" and image["archive_sha256"] == candidate["sha256"]
    metadata = json.loads(output(["docker", "image", "inspect", image["image_id"]]))[0]
    assert metadata["Config"]["Labels"]["org.opencontainers.image.revision"] == candidate["commit"]
    response = httpx.get("http://127.0.0.1:8001/protocol")
    response.raise_for_status()
    previous_manifest = response.json()
    api_container = output(COMPOSE + ["ps", "-q", "api"])
    assert api_container
    old_api = output(["docker", "inspect", "--format", "{{.Image}}", api_container])
    api_image = old_api
    if options.with_api:
        backend = json.loads((directory / "backend-verification.json").read_text())
        assert backend["status"] == "passed" and backend["archive_sha256"] == candidate["sha256"]
        api_image = backend["image_id"]
        embedded = json.loads(output(["docker", "run", "--rm", "--network", "none", api_image,
                                      "python", "-c", "from pathlib import Path; print(Path('/app/app/protocol.json').read_text())"]))
        assert embedded == candidate["manifest"]
    else:
        assert previous_manifest == candidate["manifest"]
    old_container = output(COMPOSE + ["ps", "-q", "game"])
    assert old_container
    old_image = output(["docker", "inspect", "--format", "{{.Image}}", old_container])
    before = room()
    assert before and before["phase"] == "waiting" and not before["players"], "Development room is not idle"
    assert int(redis("ZCOUNT", "im:rooms:held:room-27031", str(time.time()), "+inf")) == 0, "Room has active reservations"
    queue = output(["docker", "exec", old_container, "sh", "-c",
                    'if [ -f "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json" ]; then cat "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json"; else printf "[]"; fi'])
    assert json.loads(queue) == [], "Development result outbox must drain first"
    before_data = fingerprints()
    backup_info = None
    if options.with_api:
        backup_dir = directory / "dev-backup"
        backup_dir.mkdir(mode=0o700)
        dump = backup_dir / "database.pgdump"
        descriptor = os.open(dump, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(descriptor, "wb") as stream:
            subprocess.run(COMPOSE + ["exec", "-T", "postgres", "pg_dump", "-U", "iron", "-d", "iron_duo", "-Fc"],
                           stdout=stream, check=True, timeout=45)
        backup_info = {"path": str(dump), "sha256": hashlib.sha256(dump.read_bytes()).hexdigest(),
                       "result_outbox": [], "fingerprints": before_data}
    report_path = directory / "dev-deployment.json"
    report = {"status": "prepared", "old_image": old_image, "image_id": image["image_id"],
              "candidate_commit": candidate["commit"], "archive_sha256": candidate["sha256"],
              "scope": "Development API/game image switch; existing PostgreSQL/Redis volumes retained; published services unchanged" if options.with_api else "Development game image only",
              "old_api_image": old_api, "api_image": api_image, "old_manifest": previous_manifest,
              "backup": backup_info, "before_fingerprints": before_data,
              "preflight": {"players": 0, "reservations": 0, "pending_results": 0}}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    stopped = False
    try:
        stopped = True
        subprocess.run(COMPOSE + ["stop", "game"], cwd=ROOT, check=True, timeout=30)
        wait_expired()
        select_images(image["image_id"], api_image, options.with_api)
        deadline = time.monotonic() + 40
        while True:
            current = room()
            if current and current["instance_id"] != before["instance_id"]:
                break
            assert time.monotonic() < deadline, "Candidate did not register its room"
            time.sleep(0.5)
        for key, value in candidate["manifest"].items():
            assert current[key] == value
        container = output(COMPOSE + ["ps", "-q", "game"])
        assert output(["docker", "inspect", "--format", "{{.Image}}", container]) == image["image_id"]
        assert output(["docker", "inspect", "--format", "{{.HostConfig.RestartPolicy.Name}}", container]) == "unless-stopped"
        assert httpx.get("http://127.0.0.1:8001/protocol").json() == candidate["manifest"]
        after_data = fingerprints()
        assert after_data == before_data, "Development account or result fields changed during switch"
        api_container = output(COMPOSE + ["ps", "-q", "api"])
        assert output(["docker", "inspect", "--format", "{{.Image}}", api_container]) == api_image
        assert output(["docker", "inspect", "--format", "{{.HostConfig.RestartPolicy.Name}}", api_container]) == "unless-stopped"
        report.update(status="passed", after_fingerprints=after_data, container=container, room_id=current["room_id"],
                      phase=current["phase"], restart_policy="unless-stopped")
        print("CANDIDATE_DEV_DEPLOY_PASS " + json.dumps(report), flush=True)
    except Exception as error:
        report.update(status="failed", failure=str(error))
        if stopped:
            subprocess.run(COMPOSE + ["stop", "game"], cwd=ROOT, check=True, timeout=30)
            wait_expired()
            select_images(old_image, old_api, options.with_api)
            report["rollback_image"] = old_image
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
