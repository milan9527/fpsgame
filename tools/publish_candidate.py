"""Promote a verified candidate into idle local release services, retaining rollback data."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import httpx
from backup import create as backup
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ["docker", "compose", "-f", "compose.yaml"]
SERVICES = ["api", "game", "game2"]
ROOMS = ["room-27015", "room-27022"]


def output(args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def room(name):
    raw = output(COMPOSE + ["exec", "-T", "redis", "redis-cli", "--raw", "GET", "im:rooms:room:" + name])
    return json.loads(raw) if raw else None


def fingerprint():
    sql = "SELECT json_build_object(" + ",".join(
        f"'{table}',(SELECT md5(coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY id),'')) FROM {table} t)"
        for table in ["users", "matches", "results"]) + ")"
    return json.loads(output(COMPOSE + ["exec", "-T", "postgres", "psql", "-U", "iron", "-d", "iron", "-At", "-c", sql]))


def wait_expired():
    deadline = time.monotonic() + 25
    while any(room(name) is not None for name in ROOMS):
        assert time.monotonic() < deadline, "Release room lease did not expire"
        time.sleep(0.5)


def start_images(path, images):
    path.write_text(json.dumps({"services": {service: {"image": image, "pull_policy": "never"}
                                            for service, image in images.items()}}, indent=2) + "\n")
    subprocess.run(COMPOSE + ["-f", str(path), "up", "-d", "--no-build", "--no-deps", *SERVICES],
                   cwd=ROOT, check=True, timeout=90)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-dir", type=Path, required=True)
    args = parser.parse_args()
    directory = args.candidate_dir.resolve()
    _, candidate = candidate_command(directory)
    backend = json.loads((directory / "backend-verification.json").read_text())
    image = json.loads((directory / "server-image.json").read_text())
    assert backend["status"] == image["status"] == "passed"
    assert backend["archive_sha256"] == image["archive_sha256"] == candidate["sha256"]
    assert candidate["development_deployment"]["status"] == "passed"
    assert all(candidate["natural_round_verification"][mode]["status"] == "passed" for mode in ["solo", "duo"])
    previous = httpx.get("http://127.0.0.1:8000/protocol").json()
    assert previous["client_version"] != candidate["manifest"]["client_version"], "Already running this version"
    old_package = ROOT / "artifacts/IronMeridian-Linux"
    old_archive = ROOT / "artifacts/IronMeridian-Linux-x86_64.tar.gz"
    build = json.loads((old_package / "build.json").read_text())
    assert all(build[key] == value for key, value in previous.items())
    old_images = {}
    for service in SERVICES:
        container = output(COMPOSE + ["ps", "-q", service])
        assert container
        old_images[service] = output(["docker", "inspect", "--format", "{{.Image}}", container])
        if service != "api":
            queue = output(["docker", "exec", container, "sh", "-c",
                'if [ -f "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json" ]; then cat "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json"; else printf "[]"; fi'])
            assert json.loads(queue) == [], "Release result outbox must drain first"
    for name in ROOMS:
        state = room(name)
        assert state and state["phase"] == "waiting" and not state["players"], "Release room is occupied"
        assert int(output(COMPOSE + ["exec", "-T", "redis", "redis-cli", "--raw", "ZCOUNT",
                                    "im:rooms:held:" + name, str(time.time()), "+inf"])) == 0
    folder = ROOT / ("artifacts/release-" + candidate["manifest"]["client_version"])
    folder.mkdir(mode=0o700)
    retained = ROOT / "artifacts/releases" / previous["client_version"]
    retained.mkdir(parents=True)
    saved_archive = retained / old_archive.name
    shutil.copy2(old_archive, saved_archive)
    stage = folder / "new-runtime"
    shutil.copytree(directory / "IronMeridian-Linux", stage)
    staged_archive = folder / old_archive.name
    shutil.copy2(directory / candidate["archive"], staged_archive)
    with staged_archive.open("rb") as stream:
        assert hashlib.file_digest(stream, "sha256").hexdigest() == candidate["sha256"]
    before = fingerprint()
    saved_backup = backup()
    report_path = folder / "verification.json"
    report = {"status": "prepared", "candidate": str(directory), "manifest": candidate["manifest"],
              "archive_sha256": candidate["sha256"], "old_manifest": previous, "old_images": old_images,
              "backup": str(saved_backup), "before_fingerprints": before, "retained_release": str(retained)}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    images = {"api": backend["image_id"], "game": image["image_id"], "game2": image["image_id"]}
    stopped = False
    moved = False
    try:
        subprocess.run(COMPOSE + ["stop", "game", "game2"], cwd=ROOT, check=True, timeout=40)
        stopped = True
        wait_expired()
        start_images(folder / "compose.override.json", images)
        deadline = time.monotonic() + 60
        while True:
            try:
                ready = httpx.get("http://127.0.0.1:8000/protocol", timeout=2).json() == candidate["manifest"]
                states = [room(name) for name in ROOMS]
                ready = ready and all(state and all(state[key] == value for key, value in candidate["manifest"].items()) for state in states)
                if ready:
                    break
            except (httpx.HTTPError, ValueError):
                pass
            assert time.monotonic() < deadline, "Release endpoints did not become ready"
            time.sleep(0.5)
        assert fingerprint() == before, "Existing account or result fields changed during switch"
        for service in SERVICES:
            container = output(COMPOSE + ["ps", "-q", service])
            assert output(["docker", "inspect", "--format", "{{.Image}}", container]) == images[service]
            assert output(["docker", "inspect", "--format", "{{.HostConfig.RestartPolicy.Name}}", container]) == "unless-stopped"
        old_package.rename(retained / old_package.name)
        moved = True
        stage.rename(old_package)
        os.replace(staged_archive, old_archive)
        report.update(status="switched", images=images, after_fingerprints=fingerprint(),
                      rooms=states, published_client=True, endpoint_client_tests="pending")
        print("CANDIDATE_RELEASE_SWITCHED " + json.dumps({"folder": str(folder), "manifest": candidate["manifest"]}), flush=True)
    except Exception as error:
        report.update(status="failed", failure=str(error))
        if stopped:
            subprocess.run(COMPOSE + ["stop", "game", "game2"], cwd=ROOT, check=True, timeout=40)
            wait_expired()
            start_images(folder / "rollback.override.json", old_images)
            report["rollback_images_started"] = True
        if moved:
            if old_package.exists():
                old_package.rename(folder / "failed-runtime")
            (retained / old_package.name).rename(old_package)
            shutil.copy2(saved_archive, old_archive)
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
