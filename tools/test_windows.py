"""Run the exported Windows executable under Wine, including real AWS multiplayer."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/windows-verification"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--online-only", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(exist_ok=True)
    OUT.chmod(0o2775)  # Container's supplementary group can write non-secret evidence.
    build = json.loads((ROOT / "artifacts/windows-build/build.json").read_text())
    accounts = json.loads((ROOT / "artifacts/test-accounts.json").read_text())
    token = uuid.uuid4().hex[:8]
    containers, processes = [], []
    report = {"status": "running", "archive_sha256": build["sha256"], "checks": [],
              "scope": "Windows x64 executable under Wine 8, software OpenGL; not a physical Windows PC"}
    if args.online_only:
        previous = json.loads((OUT / "verification.json").read_text())
        assert previous["archive_sha256"] == build["sha256"]
        assert all(name in previous["checks"] for name in ["menu", "solo", "duo"])
        report["checks"] = ["menu", "solo", "duo"]

    def launch(name, script, extra_env=None, headless=False):
        container = "iron-windows-" + token + "-" + name
        containers.append(container)
        env = dict(os.environ, EXPECTED_API=build["default_api"], WINDOWS_TEST_MODE=name,
                   CAPTURE_ARTIFACT_DIR="Z:/evidence", WINEDLLOVERRIDES="mscoree,mshtml=")
        env.update(extra_env or {})
        command = ["docker", "run", "--rm", "--init", "--name", container,
                   "--network", "host", "--group-add", str(os.getgid())]
        for key in ["EXPECTED_API", "WINDOWS_TEST_MODE", "CAPTURE_ARTIFACT_DIR",
                    "WINEDLLOVERRIDES", *(extra_env or {}).keys()]:
            command += ["-e", key]
        for source, target, readonly in [
            (ROOT / "artifacts/windows-build/IronMeridian-Windows", "/work", True),
            (ROOT / "tests", "/tests", True), (OUT, "/evidence", False),
        ]:
            command += ["-v", str(source) + ":" + target + (":ro" if readonly else "")]
        command += ["iron-meridian-windows-test", "timeout", "100", "xvfb-run", "-a"]
        if headless:
            mode = extra_env["TEST_GAME_MODE"]
            command += ["sh", "-c",
                        'wineboot -u >/tmp/wineboot.log 2>&1 || exit 1; '
                        'touch "$1"; while [ ! -f "$2" ]; do sleep 0.1; done; '
                        'shift 2; exec wine "$@"', "windows-barrier",
                        "/evidence/" + token + "-" + name + ".ready",
                        "/evidence/" + token + "-" + mode + ".go"]
        else:
            command += ["wine"]
        command += ["/work/IronMeridian.exe", "--audio-driver", "Dummy", "--max-fps", "60",
                    "--log-file", "Z:/evidence/" + name + ".log",
                    "--script", "Z:/tests/" + script]
        if headless:
            command += ["--headless", "--", "--bot-client"]
        log = (OUT / (name + "-wine.log")).open("w")
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append((process, log))
        return process, log, name

    def check(item, marker):
        process, log, name = item
        code = process.wait(timeout=115)
        log.flush()
        path = OUT / (name + ".log")
        text = path.read_text() if path.exists() else ""
        if code or marker not in text or "SCRIPT ERROR" in text or "ERROR:" in text:
            raise RuntimeError(name + " failed; inspect its Windows/Wine logs")
        report["checks"].append(name)
        print("WINDOWS_CHECK_PASS " + name, flush=True)

    try:
        archive = Path(build["archive"])
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == build["sha256"]
        if not args.online_only:
            for name in ["menu", "solo", "duo"]:
                check(launch(name, "windows_runtime.gd"), "WINDOWS_RUNTIME_PASS")
                assert (OUT / ("windows-" + name + ".png")).stat().st_size > 1000
        check(launch("aim", "aim_alignment.gd"), "AIM_ALIGNMENT_PASS")
        for mode, port in [("solo", 27015), ("duo", 27022)]:
            pending = []
            for i in range(2):
                account = accounts["network-" + str(i)]
                pending.append(launch("online-" + mode + "-" + str(i), "windows_online.gd",
                    {"TEST_USERNAME": account["username"], "TEST_PASSWORD": account["password"],
                     "TEST_ROOM_ID": "room-" + str(port), "TEST_GAME_MODE": mode}, headless=True))
            deadline = time.monotonic() + 70
            while not all((OUT / (token + "-" + item[2] + ".ready")).exists() for item in pending):
                if time.monotonic() > deadline or any(item[0].poll() is not None for item in pending):
                    raise RuntimeError("Windows test environments did not both become ready")
                time.sleep(0.2)
            (OUT / (token + "-" + mode + ".go")).touch()
            for item in pending:
                check(item, "ONLINE_CLIENT_PASS")
        report["status"] = "passed"
        print("WINDOWS_VERIFY_PASS menu=ok offline_solo_duo=ok aws_online_solo_duo=ok")
    finally:
        for name in containers:
            subprocess.run(["docker", "rm", "-f", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for process, log in processes:
            process.wait(timeout=10)
            log.close()
        (OUT / "verification.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
