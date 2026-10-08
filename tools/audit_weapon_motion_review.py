#!/usr/bin/env python3
"""Audit saved motion evidence without inventing an orphaned process exit code."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ALL_CLIPS = {
    f"{view}-weapon-{weapon}": end
    for view in ("first", "third-stand", "third-crouch")
    for weapon, end in enumerate((132, 180, 192))
}


def audit_capture(base):
    base = Path(base)
    status = json.loads((base / "process-result.json").read_text())
    final = base / "motion-review.json"
    source = final if final.exists() else base / "contact-review.partial.json"
    capture = json.loads(source.read_text()) if source.exists() else {}
    errors = []
    if bool(status.get("background_materials_simplified")) != bool(capture.get("background_materials_simplified")):
        errors.append("Background diagnostic mode disagrees with runner")
    inputs = status.get("inputs_sha256", {})
    if len(inputs) < 3:
        errors.append("Missing executable/PCK/script provenance")
    for name, expected in inputs.items():
        path = Path(name)
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            errors.append(f"Input missing or changed: {name}")
    requested = status.get("requested_clips", list(ALL_CLIPS))
    if not requested or len(set(requested)) != len(requested) or set(requested) - ALL_CLIPS.keys():
        errors.append("Invalid requested clip scope")
    if "requested_clips" in status and capture.get("requested_clips") != requested:
        errors.append("Capture scope disagrees with runner")
    expected_clips = {name: ALL_CLIPS[name] for name in requested if name in ALL_CLIPS}
    groups = {}
    images = {}
    for sample in capture.get("samples", []):
        name = sample.get("name", "")
        if Path(name).name != name or "-frame-" not in name:
            errors.append(f"Invalid sample name: {name!r}")
            continue
        clip, frame_text = name.rsplit("-frame-", 1)
        groups.setdefault(clip, []).append(sample)
        if not frame_text.isdigit() or int(frame_text) != sample.get("clip_frame"):
            errors.append(f"Frame name disagrees with metadata: {name}")
        image = base / f"{name}.png"
        data = image.read_bytes() if image.is_file() else b""
        # A file merely existing does not establish a complete PNG.
        if (len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n"
                or data[-12:] != b"\x00\x00\x00\x00IEND\xaeB`\x82"):
            errors.append(f"Missing or truncated PNG: {name}")
        else:
            size = list(struct.unpack(">II", data[16:24]))
            if capture.get("viewport") and size != capture["viewport"]:
                errors.append(f"Viewport mismatch: {name}")
            images[name] = {"sha256": hashlib.sha256(data).hexdigest(), "size": size}
    clips = {}
    for clip, end in expected_clips.items():
        samples = groups.get(clip, [])
        frames = [s.get("clip_frame") for s in samples]
        complete = frames == list(range(0, end + 1, 6))
        if complete:
            complete = samples[0].get("reload_left", 0) > 0 and samples[-1].get("reload_left", 1) <= 0
        clips[clip] = {"samples": len(samples), "last_frame": frames[-1] if frames else None,
                       "timeline_complete": complete}
        if not complete:
            errors.append(f"Incomplete or unordered timeline: {clip}")
    for clip in groups.keys() - expected_clips.keys():
        errors.append(f"Unexpected clip: {clip}")
    log = (base / "capture.log").read_text(errors="replace") if (base / "capture.log").exists() else ""
    if "WEAPON_MOTION_REVIEW_PASS" not in log:
        errors.append("Missing engine completion marker")
    if any(marker in log for marker in ("SCRIPT ERROR", "Assertion failed", "ERROR:")):
        errors.append("Engine log contains errors")
    if not final.exists() or not capture.get("complete") or not capture.get("world_visible"):
        errors.append("No complete world-visible final manifest")
    evidence_complete = not errors
    exit_verified = status.get("status") == "exited" and status.get("exit_code") == 0
    return {
        "source": str(source), "evidence_complete": evidence_complete,
        "process_exit_verified": exit_verified,
        "passed": evidence_complete and exit_verified,
        "full_suite_passed": evidence_complete and exit_verified and set(requested) == ALL_CLIPS.keys(),
        "requested_clips": requested,
        "background_materials_simplified": bool(capture.get("background_materials_simplified")),
        "recorded_process_status": status.get("status"),
        "recorded_exit_code": status.get("exit_code"),
        "clips": clips, "images": images, "errors": errors,
        "limits": "10 Hz diagnostic samples do not certify between-frame contacts, lighting, locomotion or networking. An orphaned process exit code cannot be recovered from screenshots.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = audit_capture(args.capture)
    output = args.output or args.capture / "recovery-audit.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "images"}, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
