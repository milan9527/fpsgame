"""Verify the exact Android distribution's UI/input source on the build host."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/android-build"


def main():
    checks = [
        ("remembered_login", "login-memory-test", "REMEMBERED_LOGIN_PASS", False),
        ("login_memory_ui", "login-memory-ui", "LOGIN_MEMORY_UI_PASS", True),
        ("mobile_controls", "final-touch-test", "MOBILE_CONTROLS_PASS", True),
        ("aim_alignment", "aim-alignment", "AIM_ALIGNMENT_PASS", False),
        ("gyro_aim", "gyro-aim", "GYRO_AIM_PASS", True),
    ]
    for script, evidence, marker, mobile in checks:
        with tempfile.TemporaryDirectory(prefix="android-input-test-") as profile:
            env = dict(os.environ, XDG_DATA_HOME=profile, CAPTURE_ARTIFACT_DIR=str(OUT))
            command = (["xvfb-run", "-a", str(ROOT / "tools/godot"), "--audio-driver", "Dummy"]
                       if script == "gyro_aim" else [str(ROOT / "tools/godot"), "--headless"])
            command += ["--path", str(OUT / "source/client"), "--script", str(ROOT / "tests" / (script + ".gd"))]
            if mobile:
                command += ["--", "--mobile-test"]
            log = OUT / (evidence + ".log")
            with log.open("w") as stream:
                result = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=90)
            text = log.read_text()
            if result.returncode or marker not in text or "ERROR:" in text:
                raise RuntimeError("Android input check failed: " + evidence)
            print(marker, flush=True)


if __name__ == "__main__":
    main()
