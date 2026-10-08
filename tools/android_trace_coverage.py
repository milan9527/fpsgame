"""Stream atrace coverage without extracting a large trace to disk.

Coverage is only a prerequisite for scheduler analysis, not clock alignment or
proof that events inside the window were not lost.
"""
import argparse
import json
from pathlib import Path
import re
import zlib


def trace_lines(path, max_bytes=512 * 1024 * 1024):
    with Path(path).open("rb") as stream:
        prefix = stream.read(65536)
        marker = b"TRACE:\n"
        position = prefix.find(marker)
        if position < 0:
            raise ValueError("Missing atrace TRACE marker")
        decoder = zlib.decompressobj()
        compressed = prefix[position + len(marker):]
        pending = b""
        total = 0
        while True:
            # Bound each decompression allocation, including high-ratio inputs.
            data = decoder.decompress(compressed, 65536)
            compressed = decoder.unconsumed_tail
            total += len(data)
            if total > max_bytes:
                raise ValueError("Trace exceeds decompressed byte limit")
            pending += data
            lines = pending.split(b"\n")
            pending = lines.pop()
            if len(pending) > 1024 * 1024:
                raise ValueError("Trace line exceeds byte limit")
            for line in lines:
                yield line.decode("utf-8", errors="replace")
            if not compressed:
                compressed = stream.read(65536)
                if not compressed:
                    break
        if not decoder.eof:
            raise ValueError("Truncated compressed trace")
        if pending:
            yield pending.decode("utf-8", errors="replace")


def coverage(lines):
    event = re.compile(r"\[(\d+)\]\s+\S+\s+(\d+\.\d+):")
    cpus = {}
    expected = None
    entries = None
    lost_events = 0
    for line in lines:
        header = re.search(r"entries-in-buffer/entries-written:\s*(\d+)/(\d+)", line)
        if header:
            retained, written = map(int, header.groups())
            entries = {"retained": retained, "written": written,
                       "not_retained": max(0, written - retained)}
        lost = re.search(r"LOST\s+(\d+)\s+EVENTS", line)
        if lost:
            lost_events += int(lost[1])
        count = re.search(r"#P:(\d+)", line)
        if count:
            expected = int(count[1])
        match = event.search(line)
        if not match:
            continue
        cpu, stamp = match.groups()
        stamp = float(stamp)
        row = cpus.setdefault(cpu, {"start_s": stamp, "end_s": stamp, "events": 0})
        row["start_s"] = min(row["start_s"], stamp)
        row["end_s"] = max(row["end_s"], stamp)
        row["events"] += 1
    complete = expected is not None and len(cpus) == expected
    common = None
    if complete:
        start = max(row["start_s"] for row in cpus.values())
        end = min(row["end_s"] for row in cpus.values())
        if start <= end:
            common = {"start_s": start, "end_s": end}
    return {"acceptance": False, "expected_cpu_count": expected,
            "all_cpus_observed": complete, "cpu_coverage": cpus,
            "buffer_entries": entries,
            "explicit_lost_events": lost_events,
            "loss_detected": lost_events > 0 or (
                entries is not None and entries["not_retained"] > 0),
            "common_observed_window": common,
            "clock_alignment_verified": False,
            "limitation": "Observed endpoints do not prove loss-free coverage or shared presentation clock."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = coverage(trace_lines(args.trace))
    args.output.write_text(json.dumps(report, indent=2) + "\n")
