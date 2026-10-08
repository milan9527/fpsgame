"""Review diagnostic shader scopes from a single epoch-format logcat capture.

Scope durations measure CPU/driver wall time, not GPU or presentation intervals.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import math

try:
    from .android_render_stall_review import review as render_review
except ImportError:
    from android_render_stall_review import review as render_review


MARKER = "IRON_SHADER_PROBE"
OPERATIONS = ("compile_specialization", "load_cache", "save_cache", "bind_shader_total")
LINE = re.compile(
    r"^\s*(\d+\.\d+)\s+(\d+)\s+(\d+)\s+\w\s+\S+\s*:\s+"
    r"IRON_SHADER_PROBE operation=(" + "|".join(OPERATIONS) + r")"
    r" start_us=(\d+) end_us=(\d+) duration_us=(\d+)"
    r"(?: shader=(\w+) variant=(\d+) specialization=(\d+)"
    r" vertex_sha256=([0-9a-f]{64}) fragment_sha256=([0-9a-f]{64}))?\s*$"
)


def review(text):
    calls = []
    for number, line in enumerate(text.splitlines(), 1):
        if MARKER not in line:
            continue
        match = LINE.fullmatch(line)
        if not match:
            raise ValueError(f"Malformed shader probe at line {number}")
        epoch, pid, tid, operation, start, end, duration, *identity = match.groups()
        start, end, duration = int(start), int(end), int(duration)
        if end < start or end - start != duration or duration < 8000:
            raise ValueError(f"Invalid shader timing at line {number}")
        calls.append(dict(log_line=number, emitted_epoch_s=epoch,
                          pid=int(pid), tid=int(tid), operation=operation,
                          start_us=start, end_us=end, duration_us=duration))
        if identity[0] is not None:
            if operation != "compile_specialization":
                raise ValueError(f"Unexpected shader identity at line {number}")
            shader, variant, specialization, vertex, fragment = identity
            calls[-1]["identity"] = dict(
                shader=shader, variant=int(variant),
                specialization=int(specialization),
                vertex_sha256=vertex, fragment_sha256=fragment)
    overlaps = []
    for record in render_review(text)["stalls"]:
        stall = record["stall"]
        end = stall["end_ticks_usec"]
        wall = stall["render_wall_ms"]
        if (type(end) is not int or end <= 0 or
                type(wall) not in (int, float) or
                not math.isfinite(wall) or wall <= 0 or wall * 1000 > end):
            raise ValueError(f"Invalid render timing at line {record['log_line']}")
        # Both Time.get_ticks_usec() and the native probe use OS ticks.
        # Round outward by 1us to retain JSON floating-point uncertainty.
        start = end - math.ceil(wall * 1000) - 1
        selected = [c for c in calls if c["pid"] == int(record["pid"])
                    and c["start_us"] <= end and c["end_us"] >= start]
        overlaps.append({
            "render_log_line": record["log_line"],
            "pid": int(record["pid"]),
            "render_start_us_lower_bound": start,
            "render_end_us": end,
            "render_wall_ms": wall,
            "overlapping_shader_log_lines": [c["log_line"] for c in selected],
        })
    return {
        "diagnostic_only": True,
        "acceptance": False,
        "scope": "Logged shader calls >=8ms; not actual presented frame times",
        "limitations": [
            "Bind, compilation and cache scopes may nest; do not sum their durations.",
            "Log emission time is not an engine clock or presentation anchor.",
            "Use one process lifetime per input; PID reuse cannot be excluded.",
            "Missing calls do not exclude short calls or uninstrumented stalls.",
            "Diagnostic logging and the modified engine may change performance.",
            "Source hashes identify generated GLSL, not project material paths.",
            "Identity hashing/logging follows scope timing and can delay subsequent frames.",
            "Tick overlaps require the same process lifetime; they show timing, not causation.",
            "Render stalls are buffered and bounded; omitted stalls cannot be correlated.",
        ],
        "calls": calls,
        "render_tick_overlaps": overlaps,
        "operations": {
            operation: {
                "count": len(selected),
                "max_duration_us": max(
                    (call["duration_us"] for call in selected), default=None),
            }
            for operation in OPERATIONS
            for selected in [[c for c in calls if c["operation"] == operation]]
        },
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logcat", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    raw = args.logcat.read_bytes()
    result = review(raw.decode())
    result["source_sha256"] = hashlib.sha256(raw).hexdigest()
    with args.output.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")


if __name__ == "__main__":
    main()
