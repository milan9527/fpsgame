#!/usr/bin/env python3
"""Compare CPU sections from two raw captures; this is not frame acceptance."""

import argparse
import json
from pathlib import Path

from summarize_android_sections import summarize


def compare(before_path, after_path):
    before, after = summarize(before_path), summarize(after_path)
    if not before["sections"] or not after["sections"]:
        raise ValueError("both captures must contain ANDROID_SECTION records")
    rows = {}
    for name in sorted(before["sections"].keys() | after["sections"].keys()):
        left, right = before["sections"].get(name), after["sections"].get(name)

        def compact(section):
            if section is None:
                return None
            return {key: section[key] for key in (
                "count", "weighted_mean_ms_approx", "peak_ms"
            )}

        row = {"before": compact(left), "after": compact(right)}
        for field in ("weighted_mean_ms_approx", "peak_ms"):
            a = left[field] if left else None
            b = right[field] if right else None
            row[field + "_delta"] = b - a if a is not None and b is not None else None
        rows[name] = row
    return {
        "measurement": "engine_cpu_section_comparison",
        "sources": {
            label: {key: report[key] for key in (
                "source", "source_sha256", "duplicate_records_removed"
            )}
            for label, report in (("before", before), ("after", after))
        },
        "limitations": before["limitations"] + [
            "Deltas are after minus before, not proof of causality.",
            "Counts describe sampled work, not elapsed time or matched gameplay.",
            "Missing sections are null, never zero-cost measurements.",
        ],
        "sections": rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = compare(args.before, args.after)
    except ValueError as error:
        parser.error(str(error))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
