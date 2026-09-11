"""Render the verified candidate's imported character and voice UI resources."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-dir", type=Path, required=True)
    options = parser.parse_args()
    runtime, candidate = candidate_command(options.candidate_dir)
    output = options.candidate_dir.resolve() / "render-verification"
    output.mkdir(exist_ok=True)
    report = {"status": "running", "commit": candidate["commit"],
              "archive_sha256": candidate["sha256"], "checks": []}
    report_path = output / "verification.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    try:
        with tempfile.TemporaryDirectory(prefix="iron-render-profile-") as profile:
            env = dict(os.environ, XDG_DATA_HOME=profile, CAPTURE_ARTIFACT_DIR=str(output))
            for name, marker in [
                ("animation_rules", "ANIMATION_RULES_PASS"),
                ("downed_animation", "DOWNED_ANIMATION_PASS"),
                ("team_voice_ui", "TEAM_VOICE_UI_PASS"),
            ]:
                log = output / (name + ".log")
                with log.open("w") as stream:
                    result = subprocess.run(
                        ["xvfb-run", "-a"] + runtime[:-1] + ["--audio-driver", "Dummy",
                         "--script", str(ROOT / "tests" / (name + ".gd"))],
                        cwd=output, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=35)
                text = log.read_text()
                assert result.returncode == 0 and marker in text, str(log)
                assert not any(error in text for error in [
                    "SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked", "ERROR:"]), str(log)
                report["checks"].append(name)
                print(f"CANDIDATE_RENDER_CHECK_PASS {name}", flush=True)
        for image in ("downed-animation.png", "team-voice-settings.png", "microphone-setup.png"):
            assert (output / image).stat().st_size > 1000, image
        report["status"] = "passed"
        print("CANDIDATE_RENDER_PASS commit=" + candidate["commit"] + " archive_sha256=" + candidate["sha256"])
    except Exception as error:
        report.update(status="failed", failure=str(error))
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
