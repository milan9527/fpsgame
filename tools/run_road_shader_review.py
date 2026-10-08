#!/usr/bin/env python3
"""Bounded isolated shader diagnosis; never substitutes for world screenshots."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--shader", type=Path)
    parser.add_argument("--no-bump", action="store_true")
    parser.add_argument("--renderer", default="gl_compatibility",
                        choices=["gl_compatibility", "forward_plus"])
    parser.add_argument("--timeout", default=180, type=float)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    preview = args.preview.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    script = root / "tests/road_shader_draw_review.gd"
    files = [preview, preview.with_suffix(".pck"), script]
    if args.shader:
        files.append(args.shader.resolve())
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    command = ["xvfb-run", "-a", str(preview), "--path", "/tmp",
               "--rendering-method", args.renderer, "--resolution", "640x400",
               "--script", str(script)]
    env = dict(os.environ, LP_NUM_THREADS="4", CAPTURE_ARTIFACT_DIR=str(output),
               ROAD_SHADER_NO_BUMP="1" if args.no_bump else "0",
               ROAD_SHADER_PATH=str(args.shader.resolve()) if args.shader else "")
    result = dict(command=command, hashes=hashes, renderer=args.renderer,
                  no_bump=args.no_bump, diagnostic_only=True,
                  status="running", passed=False)
    result_file = output / "process-result.json"
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    started = time.monotonic()
    with (output / "capture.log").open("w") as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                   env=env, start_new_session=True)
        try:
            process.wait(timeout=args.timeout)
            result["status"] = "exited"
        except subprocess.TimeoutExpired:
            result["status"] = "timed_out"
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
    text = (output / "capture.log").read_text()
    result.update(elapsed_seconds=time.monotonic() - started, exit_code=process.returncode)
    result["passed"] = (
        process.returncode == 0 and "ROAD_SHADER_DRAW_PASS" in text
        and (output / "road-shader.png").is_file()
        and not any(marker in text for marker in ["ERROR:", "SCRIPT ERROR", "Assertion failed"])
    )
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
