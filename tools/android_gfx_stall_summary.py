"""Bounded per-thread atrace scope/gap analysis; never acceptance evidence."""
import argparse
import json
import math
from pathlib import Path

from android_scheduler_summary import HEADER
from android_trace_coverage import trace_lines


def summarize(lines, tid, tgid, start, end):
    if not all(math.isfinite(v) for v in (start, end)) or start >= end:
        raise ValueError("requires finite start < end")
    events = []
    for line in lines:
        match = HEADER.match(line)
        if (match and int(match[2]) == tid and match[3] == str(tgid)
                and match[6] == "tracing_mark_write"):
            timestamp = float(match[5])
            if start <= timestamp <= end:
                events.append((timestamp, match[7]))
    # A thread can migrate CPUs; buffer output order is not time order.
    events.sort(key=lambda event: event[0])
    stack, scopes, gaps = [], [], []
    unmatched_ends = 0
    previous = None
    for timestamp, body in events:
        if previous is not None:
            gaps.append({
                "start": previous[0], "end": timestamp,
                "duration_ms": (timestamp - previous[0]) * 1000,
                "previous_marker": previous[1], "next_marker": body,
                "open_scopes": [entry[1] for entry in stack],
            })
        previous = (timestamp, body)
        fields = body.split("|", 2)
        if len(fields) == 3 and fields[:2] == ["B", str(tgid)]:
            stack.append((timestamp, fields[2]))
        elif body in ("E", "E|" + str(tgid)):
            if stack:
                begin, name = stack.pop()
                scopes.append({"name": name, "start": begin, "end": timestamp,
                               "duration_ms": (timestamp - begin) * 1000})
            else:
                unmatched_ends += 1
    return {
        "tid": tid, "tgid": tgid, "window": [start, end],
        "marker_count": len(events), "unmatched_ends": unmatched_ends,
        "open_scopes_at_end": [entry[1] for entry in stack],
        "longest_complete_scopes": sorted(
            scopes, key=lambda row: row["duration_ms"], reverse=True)[:20],
        "largest_marker_gaps": sorted(
            gaps, key=lambda row: row["duration_ms"], reverse=True)[:20],
        "acceptance_evidence": False,
        "limitations": (
            "Only synchronous scopes wholly inside this window are paired. "
            "Missing markers and boundary scopes are unknown. Marker gaps do "
            "not identify shader compilation, driver work, or GPU waiting."),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("--tid", type=int, required=True)
    parser.add_argument("--tgid", type=int, required=True)
    parser.add_argument("--start", type=float, required=True)
    parser.add_argument("--end", type=float, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = summarize(trace_lines(args.trace), args.tid, args.tgid,
                       args.start, args.end)
    args.output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
