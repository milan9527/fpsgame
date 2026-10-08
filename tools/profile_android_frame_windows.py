"""Locate sustained frame pacing regressions; this is not an acceptance gate."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def summarize(values):
    ordered = sorted(values)
    duration = sum(values) / 1000
    return {
        "frames": len(values), "duration_s": duration,
        "fps": len(values) / duration,
        "p95_ms": ordered[math.ceil(len(values) * .95) - 1],
        "p99_ms": ordered[math.ceil(len(values) * .99) - 1],
        "over_50ms_ratio": sum(v > 50 for v in values) / len(values),
        "max_ms": max(values),
    }


def profile(values, window_seconds=30):
    if not math.isfinite(window_seconds) or window_seconds <= 0:
        raise ValueError("Window duration must be finite and positive")
    if not isinstance(values, list) or not values or any(
        type(v) not in (int, float) or not math.isfinite(v) or v <= 0
        for v in values
    ):
        raise ValueError("Expected nonempty raw positive finite frame intervals")
    windows = []
    stalls = []
    elapsed_ms = 0.
    bucket = []
    first = 0
    start = 0.
    boundary = window_seconds
    for index, value in enumerate(values):
        bucket.append(value)
        if value > 50:
            stalls.append({"frame_index": index,
                           "start_s": elapsed_ms / 1000,
                           "end_s": (elapsed_ms + value) / 1000,
                           "interval_ms": value})
        elapsed_ms += value
        elapsed = elapsed_ms / 1000
        # Keep crossing frames whole, so long stalls are never split or lost.
        if elapsed >= boundary:
            windows.append(dict(start_s=start, end_s=elapsed,
                                first_frame=first, last_frame=index,
                                reached_boundary=True,
                                **summarize(bucket)))
            bucket = []
            first = index + 1
            start = elapsed
            boundary = (math.floor(elapsed / window_seconds) + 1) * window_seconds
    if bucket:
        windows.append(dict(start_s=start, end_s=elapsed, first_frame=first,
                            last_frame=len(values) - 1, reached_boundary=False,
                            **summarize(bucket)))
    completed = [i for i, window in enumerate(windows)
                 if window["reached_boundary"]]
    comparison = None
    if len(completed) >= 2:
        early, late = windows[completed[0]], windows[completed[-1]]
        comparison = {
            "first_window_index": completed[0],
            "last_window_index": completed[-1],
            "fps_delta": late["fps"] - early["fps"],
            "p95_ms_delta": late["p95_ms"] - early["p95_ms"],
            "p99_ms_delta": late["p99_ms"] - early["p99_ms"],
            "over_50ms_ratio_delta": late["over_50ms_ratio"] - early["over_50ms_ratio"],
        }
    return {
        "scope": "Diagnostic only; no gameplay, thermal causality or acceptance assertion",
        "window_seconds": window_seconds,
        "assignment": "Whole intervals; crossing frame ends the window; final window may be short",
        "time_origin": "First retained device presentation timestamp; relative seconds. "
                       "Not a host clock or gameplay start timestamp.",
        "stalls_over_50ms": stalls,
        "first_last_boundary_windows": comparison,
        "comparison_scope": "Last minus first boundary-completed window; short tail excluded. "
                            "Null with fewer than two completed windows. Durations may differ "
                            "because crossing intervals stay whole. Not evidence of thermal causality.",
        "overall": summarize(values), "windows": windows,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--window-seconds", type=float, default=30)
    args = parser.parse_args()
    raw = args.source.read_bytes()
    data = json.loads(raw)
    report = profile(data["frame_times_ms"] if isinstance(data, dict) else data,
                     args.window_seconds)
    report.update(source=str(args.source), sha256=hashlib.sha256(raw).hexdigest())
    # New evidence files only; do not overwrite prior diagnostic snapshots.
    with args.output.open("x") as stream:
        json.dump(report, stream, indent=2)
