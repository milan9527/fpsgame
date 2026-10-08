"""Summarize complete per-thread scheduling intervals, without clock alignment.

TGID membership comes from event headers, not similar thread names. Sorting
target events handles cross-CPU ftrace ordering. Boundary intervals are omitted.
Sleeping time does not identify a blocking function or GPU cause.
"""
import argparse
import json
import math
import re
from pathlib import Path

from android_trace_coverage import trace_lines


HEADER = re.compile(
    r"^\s*(.+)-(\d+)\s+\(\s*(\d+|-+)\)\s+\[(\d+)\]\s+\S+\s+"
    r"(\d+\.\d+):\s+(\w+):\s+(.*)")
SWITCH = re.compile(r"prev_pid=(\d+).*prev_state=(\S+).*next_pid=(\d+)")
WAKE = re.compile(r"\bpid=(\d+)\b")


def summarize(source, tgid, window=None):
    if window is not None and (
            len(window) != 2 or not all(math.isfinite(v) for v in window)
            or window[0] >= window[1]):
        raise ValueError("window requires finite start < end trace timestamps")
    threads = {}
    for line in source():
        match = HEADER.match(line)
        if match and match[3].isdigit() and int(match[3]) == tgid:
            threads[int(match[2])] = match[1].strip()
    events = []
    for line in source():
        match = HEADER.match(line)
        if not match:
            continue
        stamp, kind, body = float(match[5]), match[6], match[7]
        cpu = int(match[4])
        if kind == "sched_switch":
            switch = SWITCH.search(body)
            if switch:
                prev, state, nxt = switch.groups()
                if int(prev) in threads:
                    events.append((stamp, int(prev), "out", state, cpu))
                if int(nxt) in threads:
                    events.append((stamp, int(nxt), "in", "", cpu))
        elif kind in ("sched_wakeup", "sched_wakeup_new"):
            wake = WAKE.search(body)
            if wake and int(wake[1]) in threads:
                events.append((stamp, int(wake[1]), "wake", "", cpu))
    events.sort(key=lambda event: event[0])
    states = {}
    running_cpu = {}
    rows = {tid: {"tid": tid, "name": name, "intervals": {},
                  "running_by_cpu_ms": {}, "cpu_boundary_mismatches": 0,
                  "inconsistent_transitions": 0} for tid, name in threads.items()}

    def finish(tid, stamp, exit_cpu):
        previous = states.get(tid)
        if previous is None:
            return
        state, start = previous
        # Reconstruct states from the entire trace before clipping. Filtering
        # events first would lose intervals crossing either window boundary.
        if window is not None:
            start, stamp = max(start, window[0]), min(stamp, window[1])
            if stamp <= start:
                return
        duration = (stamp - start) * 1000
        if state == "running":
            cpu = running_cpu.get(tid)
            # A complete running interval cannot migrate without switching
            # out first. Do not assign corrupt/missing boundaries to a core.
            if cpu == exit_cpu:
                totals = rows[tid]["running_by_cpu_ms"]
                key = str(cpu)
                totals[key] = totals.get(key, 0.0) + duration
            else:
                rows[tid]["cpu_boundary_mismatches"] += 1
        stats = rows[tid]["intervals"].setdefault(
            state, {"count": 0, "total_ms": 0., "max_ms": 0.,
                    "longest_intervals": []})
        stats["count"] += 1
        stats["total_ms"] += duration
        stats["max_ms"] = max(stats["max_ms"], duration)
        stats["longest_intervals"].append(
            {"start_trace_s": start, "end_trace_s": stamp, "duration_ms": duration})
        stats["longest_intervals"].sort(key=lambda item: -item["duration_ms"])
        del stats["longest_intervals"][5:]

    for stamp, tid, event, out_state, cpu in events:
        old = states.get(tid, (None, None))[0]
        if event == "wake":
            # Repeated wake notifications must not reset runnable wait time.
            if old in ("running", "runnable"):
                continue
            new = "runnable"
        elif event == "in":
            if old == "running":
                rows[tid]["inconsistent_transitions"] += 1
                states.pop(tid, None)
            elif old == "sleeping":
                # Missing wakeup: cannot separate sleep from runnable delay.
                states[tid] = ("off_cpu_unsplit", states[tid][1])
            new = "running"
        else:
            if old != "running":
                if old is not None:
                    rows[tid]["inconsistent_transitions"] += 1
                states.pop(tid, None)
            new = "runnable" if out_state.startswith("R") else "sleeping"
        finish(tid, stamp, cpu)
        states[tid] = (new, stamp)
        if event == "in":
            running_cpu[tid] = cpu
    return {
        "acceptance": False, "tgid": tgid,
        "clock_alignment_verified": False,
        "window_trace_s": list(window) if window is not None else None,
        "limitation": "Complete observed intervals only; boundaries omitted. "
                      "Scheduled running includes interrupts and does not prove useful CPU work. "
                      "Sleep does not identify blocking functions. No frame correlation.",
        "threads": sorted(rows.values(), key=lambda row: row["tid"]),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("tgid", type=int)
    parser.add_argument("output", type=Path)
    parser.add_argument("--window", nargs=2, type=float, metavar=("START", "END"),
                        help="Clip complete intervals to trace-clock seconds")
    args = parser.parse_args()
    report = summarize(lambda: trace_lines(args.trace), args.tgid, args.window)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
