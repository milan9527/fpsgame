"""Review native visual profiler CPU boundaries, never presentation FPS."""
import argparse
import heapq
import json
import math
from pathlib import Path


def review(path, first_frame=None, last_frame=None):
    if (first_frame is not None and first_frame < 0
            or last_frame is not None and last_frame < 0
            or first_frame is not None and last_frame is not None
            and first_frame > last_frame):
        raise ValueError("Invalid inclusive frame range")
    seen = {}
    longest = []
    stages = {}
    selected_frames = 0
    duplicates = 0
    hardware = []
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        record = json.loads(line)
        if record.get("message") == "visual:hardware_info":
            hardware.append(record["data"])
        if record.get("message") != "visual:profile_frame":
            continue
        data = record["data"]
        if (not isinstance(data, list) or len(data) < 2
                or type(data[0]) is not int or type(data[1]) is not int
                or data[1] < 0 or data[1] % 3 or len(data) != data[1] + 2):
            raise ValueError(f"Invalid frame layout at line {line_number}")
        identity = (record["thread_id"], data[0])
        if identity in seen:
            if seen[identity] != data:
                raise ValueError(f"Conflicting duplicate frame at line {line_number}")
            duplicates += 1
            continue
        seen[identity] = data
        selected = ((first_frame is None or data[0] >= first_frame)
                    and (last_frame is None or data[0] <= last_frame))
        selected_frames += int(selected)
        previous = None
        for offset in range(2, len(data), 3):
            name, cpu, gpu = data[offset:offset + 3]
            if (not isinstance(name, str)
                    or any(type(v) not in (int, float) or not math.isfinite(v) or v < 0
                           for v in (cpu, gpu))):
                raise ValueError(f"Invalid boundary at line {line_number}")
            if previous is not None:
                if cpu < previous[1]:
                    raise ValueError(f"CPU time regressed at line {line_number}")
                # A boundary interval can include multiple engine/driver operations.
                # Report both labels; do not assign exclusive cost to either label.
                entry = (cpu - previous[1], line_number, offset, {
                    "frame": data[0], "thread_id": identity[0],
                    "from": previous[0], "to": name,
                    "cpu_start_ms": previous[1], "cpu_end_ms": cpu,
                    "cpu_interval_ms": cpu - previous[1],
                    "source_line": line_number,
                })
                if selected:
                    heapq.heappush(longest, entry)
                    if len(longest) > 20:
                        heapq.heappop(longest)
                    key = (identity[0], previous[0], name)
                    stage = stages.setdefault(key, {
                        "thread_id": identity[0], "from": previous[0], "to": name,
                        "samples": 0, "total_cpu_interval_ms": 0,
                        "max_cpu_interval_ms": 0, "intervals_over_50ms": 0,
                    })
                    interval = cpu - previous[1]
                    stage["samples"] += 1
                    stage["total_cpu_interval_ms"] += interval
                    stage["max_cpu_interval_ms"] = max(stage["max_cpu_interval_ms"], interval)
                    stage["intervals_over_50ms"] += int(interval > 50)
            previous = (name, cpu)
    return {
        "acceptance_evidence": False,
        "measurement": "CPU cumulative timestamp differences between adjacent native boundaries",
        "limitations": "Profiler overhead applies. No presentation FPS or exclusive function attribution.",
        "unique_frames": len(seen), "duplicate_frames": duplicates,
        "selected_frames": selected_frames,
        "inclusive_frame_filter": {"first": first_frame, "last": last_frame},
        "hardware_records": hardware,
        "stage_intervals": sorted(stages.values(),
                                  key=lambda item: item["total_cpu_interval_ms"], reverse=True),
        "largest_cpu_intervals": [entry[3] for entry in sorted(longest, reverse=True)],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--first-frame", type=int)
    parser.add_argument("--last-frame", type=int)
    args = parser.parse_args()
    report = review(args.raw, args.first_frame, args.last_frame)
    with args.output.open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")


if __name__ == "__main__":
    main()
