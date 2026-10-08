#!/usr/bin/env python3
"""Run a frozen preview capture with a bounded lifetime and durable outcome."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def terminate_capture(signum, frame):
    # Route supervisor termination through the same durable cleanup as Ctrl-C.
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, terminate_capture)
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--pose", action="append", choices=[
        "default-spawn", "ads", "reload-middle", "reload-complete"])
    parser.add_argument("--timeout", type=int, default=1200)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    preview = args.preview.resolve()
    script = root / "tests/sleeve_pose_review_capture.gd"
    inputs = [preview, preview.with_suffix(".pck"), script]
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output = args.output.resolve()
    # Never confuse a failed attempt with screenshots left by a previous run.
    if output.exists() and any(output.iterdir()):
        parser.error("--output must be new or empty")
    output.mkdir(parents=True, exist_ok=True)
    command = ["xvfb-run", "-a", "-s", "-screen 0 1280x800x24",
               str(preview), "--path", "/tmp", "--rendering-method",
               "forward_plus", "--audio-driver", "Dummy", "--resolution", "1280x800",
               "--script", str(script)]
    result = {
        "command": command, "timeout_seconds": args.timeout,
        "capture_filter": args.pose or [],
        "inputs_sha256": {
            str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in inputs},
        "passed": False, "status": "running",
    }

    def persist():
        temporary = output / "process-result.tmp"
        temporary.write_text(json.dumps(result, indent=2) + "\n")
        temporary.replace(output / "process-result.json")

    persist()
    started = time.monotonic()
    process = None
    try:
        with (output / "capture.log").open("w") as log:
            process = subprocess.Popen(
                command, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True,
                env=dict(os.environ, CAPTURE_ARTIFACT_DIR=str(output),
                         REVIEW_POSES=",".join(args.pose or []),
                         LP_NUM_THREADS="4"))
            result["pid"] = process.pid
            persist()
            try:
                result["exit_code"] = process.wait(timeout=args.timeout)
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
        audit_path = output / "sleeve-pose-review.json"
        audit = json.loads(audit_path.read_text()) if audit_path.exists() else {}
        expected = set(args.pose or [
            "default-spawn", "ads", "reload-middle", "reload-complete"])
        recorded = {pose["name"] for pose in audit.get("poses", [])}
        text = (output / "capture.log").read_text()
        result["passed"] = (
            result["status"] == "exited" and result["exit_code"] == 0
            and audit.get("passed") is True and expected == recorded
            and all((output / f"{pose}.png").is_file() for pose in expected)
            and "SLEEVE_POSE_REVIEW_PASS" in text
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
