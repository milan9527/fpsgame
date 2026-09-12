"""Install an already verified server image into the idle development room only."""
import argparse
import json
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


def select_image(image_id):
    OVERRIDE.write_text(json.dumps({"services": {"game": {"image": image_id, "pull_policy": "never"}}}, indent=2) + "\n")
    subprocess.run(COMPOSE + ["-f", str(OVERRIDE), "up", "-d", "--no-deps", "--no-build", "game"],
                   cwd=ROOT, check=True, timeout=60)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-dir", type=Path, required=True)
    options = parser.parse_args()
    directory = options.candidate_dir.resolve()
    _, candidate = candidate_command(directory)
    image = json.loads((directory / "server-image.json").read_text())
    assert image["status"] == "passed" and image["archive_sha256"] == candidate["sha256"]
    metadata = json.loads(output(["docker", "image", "inspect", image["image_id"]]))[0]
    assert metadata["Config"]["Labels"]["org.opencontainers.image.revision"] == candidate["commit"]
    response = httpx.get("http://127.0.0.1:8001/protocol")
    response.raise_for_status()
    assert response.json() == candidate["manifest"]
    old_container = output(COMPOSE + ["ps", "-q", "game"])
    assert old_container
    old_image = output(["docker", "inspect", "--format", "{{.Image}}", old_container])
    before = room()
    assert before and before["phase"] == "waiting" and not before["players"], "Development room is not idle"
    assert int(redis("ZCOUNT", "im:rooms:held:room-27031", str(time.time()), "+inf")) == 0, "Room has active reservations"
    queue = output(["docker", "exec", old_container, "sh", "-c",
                    'if [ -f "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json" ]; then cat "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json"; else printf "[]"; fi'])
    assert json.loads(queue) == [], "Development result outbox must drain first"
    report_path = directory / "dev-deployment.json"
    report = {"status": "prepared", "old_image": old_image, "image_id": image["image_id"],
              "candidate_commit": candidate["commit"], "archive_sha256": candidate["sha256"],
              "scope": "Development game only; API, PostgreSQL, Redis and published services unchanged",
              "preflight": {"players": 0, "reservations": 0, "pending_results": 0}}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    stopped = False
    try:
        subprocess.run(COMPOSE + ["stop", "game"], cwd=ROOT, check=True, timeout=30)
        stopped = True
        wait_expired()
        select_image(image["image_id"])
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
        report.update(status="passed", container=container, room_id=current["room_id"],
                      phase=current["phase"], restart_policy="unless-stopped")
        print("CANDIDATE_DEV_DEPLOY_PASS " + json.dumps(report), flush=True)
    except Exception as error:
        report.update(status="failed", failure=str(error))
        if stopped:
            subprocess.run(COMPOSE + ["stop", "game"], cwd=ROOT, check=True, timeout=30)
            wait_expired()
            select_image(old_image)
            report["rollback_image"] = old_image
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
