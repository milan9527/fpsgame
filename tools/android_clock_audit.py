"""Audit measured touch/trace clock offsets; never infer global synchronization."""
import argparse
from decimal import Decimal
import json
from pathlib import Path
import re

from android_multitouch import clock_anchors
from android_trace_coverage import trace_lines


def trace_sync_markers(lines):
    """Retain atrace clock samples without treating samples as global alignment."""
    pattern = re.compile(
        r"\[\d+\]\s+\S+\s+(\d+\.\d+):\s+tracing_mark_write:\s+"
        r"trace_event_clock_sync:\s+(parent_ts|realtime_ts)=(\d+(?:\.\d+)?)\s*$")
    markers = []
    for line in lines:
        match = pattern.search(line)
        if not match:
            continue
        stamp, clock, value = match.groups()
        trace_ns = int(Decimal(stamp) * 1_000_000_000)
        # atrace parent_ts is seconds; realtime_ts is milliseconds.
        sample_ns = int(Decimal(value) * (
            1_000_000_000 if clock == "parent_ts" else 1_000_000))
        markers.append({
            "trace_timestamp_ns": trace_ns, "clock": clock,
            "sample_timestamp_ns": sample_ns,
            "sample_minus_trace_ns": sample_ns - trace_ns,
            "raw_line": line.rstrip(),
        })
    return {
        "markers": markers,
        "clock_alignment_verified": False,
        "limitation": (
            "Markers are individual samples with timestamp quantization and "
            "unbounded sampling-to-write delay, not guaranteed offset bounds. "
            "They do not establish the SurfaceFlinger presentation clock."),
    }


def audit(trace_status, records):
    selected = re.findall(r"\[([^\]]+)\]", trace_status.get("trace_clock", ""))
    report = {
        "acceptance": False, "clock_alignment_verified": False,
        "selected_trace_clocks": selected, "cycles": [],
        "limitation": (
            "Consistent endpoint samples do not prove the offset between samples. "
            "Suspend may change boot-minus-monotonic. Trace coverage and the "
            "presentation timestamp clock must be checked separately."),
    }
    for record in records:
        item = {"cycle": record.get("cycle"), "sample_offsets_consistent": False}
        report["cycles"].append(item)
        try:
            # Recompute from raw markers, not cached derived fields.
            anchors = clock_anchors(record.get("stderr", ""))
            if selected != ["boot"]:
                raise ValueError("Trace clock is not uniquely selected boot")
            if not trace_status.get("started") or not trace_status.get("stopped"):
                raise ValueError("Trace capture did not start and stop successfully")
            if [a.get("stage") for a in anchors] != ["start", "injection_end"]:
                raise ValueError("Missing, duplicate or unordered injection endpoints")
            if any("boot_minus_monotonic_min_ns" not in a for a in anchors):
                raise ValueError("Missing measured boot clock anchors")
            if anchors[1]["monotonic_before_ns"] < anchors[0]["boot_monotonic_after_ns"]:
                raise ValueError("Injection endpoint clocks overlap or regress")
            bounds = [[a["boot_minus_monotonic_min_ns"],
                       a["boot_minus_monotonic_max_ns"]] for a in anchors]
            item["sample_offset_bounds_ns"] = bounds
            lower, upper = max(b[0] for b in bounds), min(b[1] for b in bounds)
            if lower > upper:
                raise ValueError("Endpoint offsets disagree; do not correlate clocks")
            item["sample_offset_intersection_ns"] = [lower, upper]
            item["sample_offsets_consistent"] = True
        except (ValueError, TypeError, KeyError) as exc:
            item["error"] = str(exc)
    report["all_sample_offsets_consistent"] = bool(report["cycles"]) and all(
        item["sample_offsets_consistent"] for item in report["cycles"])
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace_status", type=Path)
    parser.add_argument("touch_records", type=Path, help="Touch receipt JSONL")
    parser.add_argument("output", type=Path)
    parser.add_argument("--trace", type=Path, help="Optional compressed atrace capture")
    args = parser.parse_args()
    records = [json.loads(line) for line in args.touch_records.read_text().splitlines()
               if line.strip()]
    result = audit(json.loads(args.trace_status.read_text()), records)
    if args.trace:
        result["trace_sync"] = trace_sync_markers(trace_lines(args.trace))
    args.output.write_text(json.dumps(result, indent=2) + "\n")
