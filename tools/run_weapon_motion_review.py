#!/usr/bin/env python3
"""Capture all nine reload clips; compact shadow-free mode diagnoses motion only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time
from audit_weapon_motion_review import ALL_CLIPS, audit_capture


def terminate_capture(signum, frame):
    # A terminated wrapper must not leave rendering children and stale "running".
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, terminate_capture)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compact", action="store_true",
                        help="640x400 Forward+ without light shadows; contact diagnosis only")
    parser.add_argument("--compatibility-diagnostic", action="store_true",
                        help="Use OpenGL at 640x400 without shadows for motion diagnosis, not visual acceptance")
    parser.add_argument("--cull-distant-details", action="store_true",
                        help="Diagnostic only: hide small world meshes farther than 12m from both review positions")
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--simplify-world-materials", action="store_true",
                        help="Motion diagnosis only: plain world material, no SSAO/SSIL/MSAA; actors retain materials")
    parser.add_argument("--clip", action="append", choices=list(ALL_CLIPS),
                        help="Capture selected reload clips; omitted means all nine. A subset cannot pass the full suite.")
    parser.add_argument("--side-contact", action="store_true",
                        help="Closer third-person side view for shoulder, elbow and hand contact review")
    args = parser.parse_args()
    requested = list(dict.fromkeys(args.clip or ALL_CLIPS))
    root = Path(__file__).resolve().parents[1]
    script = root / "tests/weapon_motion_review_capture.gd"
    preview = args.preview.resolve()
    inputs = [preview, preview.with_suffix(".pck"), script]
    if args.timeout <= 0 or not all(p.is_file() for p in inputs):
        parser.error("positive timeout and existing executable, PCK and script required")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error("output must be new or empty")
    output.mkdir(parents=True, exist_ok=True)
    if args.compatibility_diagnostic:
        args.compact = True
    renderer = "gl_compatibility" if args.compatibility_diagnostic else "forward_plus"
    resolution = "640x400" if args.compact else "1280x800"
    command = ["xvfb-run", "-a", "-s", f"-screen 0 {resolution}x24",
               str(preview), "--path", "/tmp", "--rendering-method", renderer,
               "--audio-driver", "Dummy",
               "--resolution", resolution, "--script", str(script)]
    result = {"command": command, "passed": False, "status": "running",
              "requested_clips": requested, "full_suite_passed": False,
              "side_contact_camera": args.side_contact,
              "timeout_seconds": args.timeout,
              "renderer": renderer, "light_shadows_disabled": args.compact,
              "distant_details_culled": args.cull_distant_details,
              "background_materials_simplified": args.simplify_world_materials,
              "profile": ("compatibility-motion-diagnostic" if args.compatibility_diagnostic else
                          "compact-motion-diagnostic" if args.compact else "preview-forward-plus"),
              "inputs_sha256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}}
    def persist():
        temporary = output / "process-result.tmp"
        temporary.write_text(json.dumps(result, indent=2) + "\n")
        temporary.replace(output / "process-result.json")
    persist()
    started = time.monotonic()
    with (output / "capture.log").open("w") as log:
        try:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True, env=dict(os.environ, LP_NUM_THREADS="4",
                CONTACT_COMPACT="1" if args.compact else "0", CONTACT_WORLD_VISIBLE="1",
                CONTACT_CULL_DETAILS="1" if args.cull_distant_details else "0",
                CONTACT_SIMPLIFY_WORLD="1" if args.simplify_world_materials else "0",
                CONTACT_REVIEW_CLIPS=",".join(requested),
                CONTACT_SIDE_CAMERA="1" if args.side_contact else "0",
                CAPTURE_ARTIFACT_DIR=str(output)))
        except OSError as error:
            result.update(status="launch_error", error=str(error),
                          elapsed_seconds=round(time.monotonic() - started, 3))
            persist()
            print(json.dumps(result, indent=2))
            return 1
        result["pid"] = process.pid
        persist()
        try:
            process.wait(timeout=args.timeout)
            result["status"] = "exited"
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            result["status"] = type(error).__name__
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
            result.update(exit_code=process.returncode,
                          elapsed_seconds=round(time.monotonic() - started, 3))
            persist()
    audit_path = output / "motion-review.json"
    audit = json.loads(audit_path.read_text()) if audit_path.exists() else {}
    samples = audit.get("samples", [])
    expected = set(requested)
    clips = {}
    for sample in samples:
        clips.setdefault(sample["name"].split("-frame-")[0], []).append(sample)
    complete = set(clips) == expected and all(
        frames[0]["clip_frame"] == 0 and frames[-1]["reload_left"] <= 0
        and len(frames) >= 10
        and all(0 < b["clip_frame"] - a["clip_frame"] <= 6 for a, b in zip(frames, frames[1:]))
        for frames in clips.values())
    text = (output / "capture.log").read_text()
    result.update(samples=len(samples), clips={k: len(v) for k, v in clips.items()})
    result["passed"] = bool(process.returncode == 0 and audit.get("complete")
        and audit.get("world_visible") and complete
        and all((output / (s["name"] + ".png")).is_file() for s in samples)
        and "WEAPON_MOTION_REVIEW_PASS" in text
        and not any(e in text for e in ("SCRIPT ERROR", "Assertion failed", "ERROR:")))
    partial_path = output / "contact-review.partial.json"
    if not result["passed"] and partial_path.exists():
        result["partial_samples"] = len(json.loads(partial_path.read_text()).get("samples", []))
    persist()
    # Independently check exact timelines, image integrity and unchanged inputs.
    evidence = audit_capture(output)
    (output / "recovery-audit.json").write_text(json.dumps(evidence, indent=2) + "\n")
    result["passed"] = result["passed"] and evidence["passed"]
    result["full_suite_passed"] = result["passed"] and evidence["full_suite_passed"]
    persist()
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
