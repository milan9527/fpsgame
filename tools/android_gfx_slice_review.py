"""Review synchronous atrace slices; durations are wall time, not GPU time."""
import argparse
import hashlib
import heapq
import json
import math
from pathlib import Path
import re

try:
    from .android_trace_coverage import trace_lines
except ImportError:
    from android_trace_coverage import trace_lines


EVENT = re.compile(
    r"-(\d+)\s+(?:\([^)]*\)\s+)?\[\d+\]\s+\S+\s+"
    r"(\d+\.\d+):\s+tracing_mark_write:\s*(.*)$"
)


def review(lines, limit=100, pid_filter=None, tid_filter=None,
           window_start=None, window_end=None):
    for bound in (window_start, window_end):
        if bound is not None and not math.isfinite(bound):
            raise ValueError("Window bounds must be finite")
    if window_start is not None and window_end is not None and window_start >= window_end:
        raise ValueError("Window start must precede end")
    stacks = {}
    longest = []
    completed = unmatched = discarded = ignored = loss = 0
    sequence = 0
    previous = {}
    for line in lines:
        lost = re.search(r"LOST\s+(\d+)\s+EVENTS", line)
        if lost:
            loss += int(lost[1])
            discarded += sum(map(len, stacks.values()))
            stacks.clear()
        match = EVENT.search(line)
        if not match:
            continue
        tid, stamp, payload = match.groups()
        stamp = float(stamp)
        stack = stacks.setdefault(tid, [])
        if stamp < previous.get(tid, stamp):
            discarded += len(stack)
            stack.clear()
        previous[tid] = stamp
        if payload.startswith("B|"):
            fields = payload.split("|", 2)
            if len(fields) == 3 and fields[1].isdigit():
                stack.append((stamp, fields[1], fields[2]))
            else:
                ignored += 1
        elif payload == "E" or re.fullmatch(r"E\|\d+", payload):
            if not stack:
                unmatched += 1
                continue
            start, pid, name = stack.pop()
            if pid_filter is not None and int(pid) != pid_filter:
                continue
            if tid_filter is not None and int(tid) != tid_filter:
                continue
            # Pair the entire trace before filtering: enclosing calls may begin
            # before the window and end after it. Keep full inclusive durations.
            if window_start is not None and stamp <= window_start:
                continue
            if window_end is not None and start >= window_end:
                continue
            duration = (stamp - start) * 1000
            completed += 1
            sequence += 1
            row = {"tid": int(tid), "pid": int(pid), "name": name,
                   "start_s": start, "end_s": stamp, "wall_ms": duration}
            heapq.heappush(longest, (duration, sequence, row))
            if len(longest) > limit:
                heapq.heappop(longest)
        else:
            ignored += 1
    return {
        "acceptance": False, "completed_slices": completed,
        "pid_filter": pid_filter,
        "unmatched_ends": unmatched, "discarded_begins": discarded,
        "open_begins": sum(map(len, stacks.values())),
        "explicit_lost_events": loss, "ignored_markers": ignored,
        "longest_slices": [row for _, _, row in sorted(longest, reverse=True)],
        "clock_alignment_verified": False,
        "limitation": "Synchronous inclusive wall durations only; nested slices overlap. "
                      "Does not establish GPU work, presentation timing or causation. "
                      "Inspect trace coverage separately for overwritten events.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--pid", type=int, help="Keep slices belonging to this process")
    parser.add_argument("--tid", type=int, help="Keep slices from this thread")
    parser.add_argument("--start", type=float, help="Window start in trace seconds")
    parser.add_argument("--end", type=float, help="Window end in trace seconds")
    args = parser.parse_args()
    report = review(trace_lines(args.trace), pid_filter=args.pid, tid_filter=args.tid,
                    window_start=args.start, window_end=args.end)
    with args.trace.open("rb") as source:
        report["source_sha256"] = hashlib.file_digest(source, "sha256").hexdigest()
    with args.output.open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
