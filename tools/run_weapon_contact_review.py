#!/usr/bin/env python3
"""Capture sampled contacts; never certify continuous motion from still images."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def interrupt(signum, frame):
    raise KeyboardInterrupt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--scope", choices=["all", "other-weapons-and-third", "third-only"],
                        default="all")
    parser.add_argument("--timeout", type=int, default=2400)
    parser.add_argument("--display-number", type=int,
                        help="Dedicated Xvfb display number for concurrent capture jobs")
    args = parser.parse_args()
    if args.display_number is not None and args.display_number < 1:
        parser.error("--display-number must be positive")
    preview = args.preview.resolve()
    script = Path(__file__).resolve().parents[1] / "tests/weapon_contact_review_capture.gd"
    inputs = [preview, preview.with_suffix(".pck"), script]
    if args.timeout <= 0 or not all(path.is_file() for path in inputs):
        parser.error("positive timeout and existing preview, PCK and script required")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error("--output must be new or empty")
    output.mkdir(parents=True, exist_ok=True)
    expected = {"third-stand-reload-middle", "third-crouch-reload-middle"}
    if args.scope != "third-only":
        weapons = [1, 2] if args.scope == "other-weapons-and-third" else [0, 1, 2]
        phases = [50] if args.scope == "other-weapons-and-third" else [36, 50, 60, 74, 86]
        expected.update(f"weapon-{weapon}-reload-{phase:02d}"
                        for weapon in weapons for phase in phases)
    display = ["-a"] if args.display_number is None else ["--server-num", str(args.display_number)]
    command = ["xvfb-run", *display, "-s", "-screen 0 1280x800x24", str(preview),
               "--path", "/tmp", "--rendering-method", "forward_plus", "--audio-driver", "Dummy",
               "--resolution", "1280x800", "--script", str(script)]
    result = dict(command=command, scope=args.scope, expected=sorted(expected),
                  passed=False, status="running", timeout_seconds=args.timeout,
                  inputs_sha256={str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in inputs})

    def persist():
        temporary = output / "process-result.tmp"
        temporary.write_text(json.dumps(result, indent=2) + "\n")
        temporary.replace(output / "process-result.json")

    signal.signal(signal.SIGTERM, interrupt)
    started = time.monotonic()
    persist()
    try:
        with (output / "capture.log").open("w") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True, env=dict(os.environ, LP_NUM_THREADS="4",
                    CAPTURE_ARTIFACT_DIR=str(output), CONTACT_CAPTURE_SCOPE=args.scope))
            result["pid"] = process.pid
            persist()
            try:
                process.wait(timeout=args.timeout)
                result["status"] = "exited"
            except subprocess.TimeoutExpired:
                result["status"] = "timed_out"
            except KeyboardInterrupt:
                result["status"] = "interrupted"
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                result["exit_code"] = process.returncode
        path = output / "contact-review.json"
        audit = json.loads(path.read_text()) if path.exists() else {}
        samples = audit.get("samples", [])
        recorded = {sample["name"] for sample in samples}
        text = (output / "capture.log").read_text()
        result["recorded"] = sorted(recorded)
        result["passed"] = (
            result["status"] == "exited" and result["exit_code"] == 0
            and audit.get("complete") is True and recorded == expected
            and len(samples) == len(expected)
            and all((output / f"{name}.png").is_file() for name in expected)
            and "WEAPON_CONTACT_REVIEW_PASS" in text
            and not any(s in text for s in ["SCRIPT ERROR", "ERROR:", "Assertion failed"]))
    except (OSError, ValueError, KeyError) as error:
        result.update(status="error", error=str(error))
    finally:
        result["elapsed_seconds"] = round(time.monotonic() - started, 3)
        persist()
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
