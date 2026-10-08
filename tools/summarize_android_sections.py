#!/usr/bin/env python3
"""Summarize one Android logcat capture, without treating CPU timings as FPS."""

import argparse
import hashlib
import json
import re
from pathlib import Path


SECTION = re.compile(
    r"ANDROID_SECTION name=(\S+) mean_ms=(\d+(?:\.\d+)?) "
    r"peak_ms=(\d+(?:\.\d+)?) count=(\d+)"
)


def summarize(path):
    sections = {}
    digest = hashlib.sha256()
    seen_records = set()
    duplicate_records = 0
    with path.open("rb") as capture:
        for line_number, raw in enumerate(capture, 1):
            digest.update(raw)
            line = raw.decode("utf-8", errors="replace").rstrip()
            match = SECTION.search(line)
            if not match:
                continue
            # Device Farm can concatenate overlapping logcat dumps. Only
            # deduplicate records with a timestamp and process/thread identity;
            # equal measurements at different times are independent windows.
            prefix = line[:match.start()].rstrip()
            timestamped = re.match(
                r"^\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+\d+\s+\d+\s", prefix
            )
            if timestamped:
                identity = (prefix, match.group(0))
                if identity in seen_records:
                    duplicate_records += 1
                    continue
                seen_records.add(identity)
            name, mean, peak, count = match.groups()
            sections.setdefault(name, []).append({
                "line": line_number,
                "log_prefix": prefix,
                "mean_ms": float(mean),
                "peak_ms": float(peak),
                "count": int(count),
            })
    summaries = {}
    for name, windows in sections.items():
        count = sum(window["count"] for window in windows)
        summaries[name] = {
            "count": count,
            "weighted_mean_ms_approx": (
                sum(w["mean_ms"] * w["count"] for w in windows) / count
                if count else None
            ),
            "peak_ms": max(w["peak_ms"] for w in windows),
            "windows": windows,
        }
    return {
        "source": str(path),
        "source_sha256": digest.hexdigest(),
        "measurement": "engine_cpu_sections",
        "duplicate_records_removed": duplicate_records,
        "limitations": [
            "Rounded window means; weighted means are approximate.",
            "Sections can overlap or nest; do not sum them as frame cost.",
            "Exact repeated timestamped records are counted once; use one capture per run.",
            "Not presented frame intervals and not Android acceptance evidence.",
        ],
        "sections": summaries,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logcat", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = summarize(args.logcat)
    if not report["sections"]:
        parser.error("capture contains no ANDROID_SECTION records")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
