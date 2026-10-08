"""Find possible temporal overlap, never infer a shared frame or stall cause.

Inputs must come from one device/run: actual-present nanoseconds, epoch logcat,
and multitouch command JSONL. No host clock or engine FPS substitutes are used.
"""
import argparse
import hashlib
import json
from pathlib import Path

try:
    from .android_multitouch import clock_anchors
    from .android_render_stall_review import review
except ImportError:
    from android_multitouch import clock_anchors
    from android_render_stall_review import review


def align(timestamps, commands, logcat, max_anchor_age_s=2):
    if (len(timestamps) < 2 or
            any(type(t) is not int or t <= 0 for t in timestamps) or
            any(b <= a for a, b in zip(timestamps, timestamps[1:]))):
        raise ValueError("Expected strictly increasing actual-present integer ns")
    if max_anchor_age_s <= 0:
        raise ValueError("Anchor age must be positive")
    # Recompute bounds from raw stderr rather than trusting derived JSON fields.
    anchors = [a for c in commands for a in clock_anchors(c.get("stderr", ""))]
    stalls = review(logcat)["stalls"]
    gaps = []
    for start, end in zip(timestamps, timestamps[1:]):
        if end - start <= 50_000_000:
            continue
        item = dict(start_present_ns=start, end_present_ns=end,
                    interval_ms=(end-start)/1e6)
        gaps.append(item)
        nearby = [a for a in anchors if max(
            abs(start-a["monotonic_before_ns"]),
            abs(end-a["monotonic_after_ns"])) <= max_anchor_age_s*1e9]
        if not nearby:
            item["unresolved"] = "No device anchor near both gap endpoints"
            continue
        low = max(a["epoch_minus_monotonic_min_ns"] for a in nearby)
        high = min(a["epoch_minus_monotonic_max_ns"] for a in nearby)
        item["nearby_anchors"] = nearby
        if low > high:
            item["unresolved"] = "Local offset brackets disagree; clock change/drift"
            continue
        # Use the union, not the tighter intersection, to retain measured spread.
        low = min(a["epoch_minus_monotonic_min_ns"] for a in nearby)
        high = max(a["epoch_minus_monotonic_max_ns"] for a in nearby)
        item.update(start_epoch_ns_bounds=[start+low, start+high],
                    end_epoch_ns_bounds=[end+low, end+high],
                    measured_offset_spread_ns=high-low,
                    possible_engine_overlaps=[])
        for stall in stalls:
            if "unresolved" in stall:
                continue
            # Float epoch conversion receives an extra 1us numerical envelope.
            left = int(stall["start_epoch_s"]*1e9)-1000
            right = int(stall["end_epoch_s"]*1e9)+1000
            if left <= end+high and right >= start+low:
                item["possible_engine_overlaps"].append({
                    "log_line": stall["log_line"], "pid": stall["pid"],
                    "engine_epoch_envelope_ns": [left, right],
                    "engine_anchor_age_ms": abs(
                        stall["stall"]["end_ticks_usec"] -
                        stall["anchor"]["ticks_before_usec"])/1000,
                    "stall": stall["stall"],
                })
    return {
        "scope": "Possible temporal overlap only; not frame identity or acceptance",
        "limitations": [
            "Inputs must be from the same device session and SurfaceView.",
            "Bounds include sampled read/epoch quantization, not unsampled clock drift.",
            "Wall-clock changes between anchors remain undetectable.",
            "Engine flush anchor can be distant; inspect engine_anchor_age_ms.",
            "CPU/driver render wall time is not GPU completion or presentation time.",
            "Absence of overlap does not establish absence of a rendering stall.",
        ],
        "max_touch_anchor_age_s": max_anchor_age_s,
        "device_anchor_count": len(anchors), "gaps_over_50ms": gaps,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("timestamps", type=Path)
    parser.add_argument("commands", type=Path)
    parser.add_argument("logcat", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = align(json.loads(args.timestamps.read_text()),
                   [json.loads(s) for s in args.commands.read_text().splitlines() if s],
                   args.logcat.read_text())
    result["source_sha256"] = {
        str(p): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (args.timestamps, args.commands, args.logcat)}
    with args.output.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")


if __name__ == "__main__":
    main()
