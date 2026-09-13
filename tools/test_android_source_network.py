"""Check the Android distribution's exact game/touch source against live AWS rooms.

Runs on Linux; this complements, and does not replace, installed APK verification.
"""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/android-build"


def main():
    accounts = json.loads((ROOT / "artifacts/test-accounts.json").read_text())
    build = json.loads((OUT / "build.json").read_text())
    report = {"apk_sha256": build["sha256"], "status": "running", "scope": "Android distribution source on Linux; live AWS HTTPS/UDP", "checks": []}
    for mode, port in [("solo", 27015), ("duo", 27022)]:
        processes = []
        try:
            for i in range(2):
                account = accounts["network-" + str(i)]
                env = dict(os.environ, TEST_USERNAME=account["username"], TEST_PASSWORD=account["password"],
                           TEST_GAME_MODE=mode, TEST_ROOM_ID="room-" + str(port),
                           XDG_DATA_HOME=str(OUT / ("profile-" + mode + str(i))))
                log = OUT / f"network-{mode}-{i}.log"
                stream = log.open("w")
                process = subprocess.Popen([
                    str(ROOT / "tools/godot"), "--headless", "--path", str(OUT / "source/client"),
                    "--max-fps", "60", "--script", str(ROOT / "tests/ssh_tunnel_client.gd"),
                    "--", "--bot-client", "--mobile-test"], env=env, stdout=stream, stderr=subprocess.STDOUT)
                processes.append((process, stream, log))
            for process, stream, log in processes:
                code = process.wait(timeout=80)
                stream.flush()
                text = log.read_text()
                if code or "ONLINE_CLIENT_PASS" not in text or "SCRIPT ERROR" in text or "ERROR:" in text:
                    raise RuntimeError("Android source network failed: " + log.name)
            for i in range(2):
                account = accounts["network-" + str(i)]
                env = dict(os.environ, TEST_USERNAME=account["username"], TEST_PASSWORD=account["password"],
                           TEST_API_URL=build["default_api"],
                           XDG_DATA_HOME=str(OUT / ("profile-" + mode + str(i))))
                result = subprocess.run([str(ROOT / "tools/godot"), "--headless", "--path", str(OUT / "source/client"),
                    "--script", str(ROOT / "tests/remembered_login_authenticated.gd")],
                    env=env, capture_output=True, text=True, timeout=30)
                if result.returncode or "AUTHENTICATED_LOGIN_RESTART_PASS" not in result.stdout:
                    raise RuntimeError("Authenticated login persistence failed")
            report["checks"].append(mode)
            print("ANDROID_SOURCE_NETWORK_PASS " + mode, flush=True)
        finally:
            for process, stream, _log in processes:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                stream.close()
    (OUT / "login-memory-auth.json").write_text(json.dumps({"status": "passed",
        "apk_sha256": build["sha256"], "profiles": 4}, indent=2) + "\n")
    report["status"] = "passed"
    (OUT / "source-network.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
