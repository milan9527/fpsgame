"""Correlate buffered engine render stalls with epoch logcat route samples.

This is diagnostic CPU/driver wall time, not presentation or acceptance data.
Requires epoch-format logcat and explicit engine clock anchors from one session.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re


LINE = re.compile(
    r"^\s*(\d+\.\d+)\s+(\d+)\s+\d+\s+\w\s+\S+\s*:\s+"
    r"ANDROID_(RENDER_CLOCK|RENDER_STALL|ROUTE)\s+(?:route_json=)?(\{.*\})$")


def review(text):
    records = []
    for number, line in enumerate(text.splitlines(), 1):
        match = LINE.match(line)
        if not match and re.search(
                r"\bANDROID_(?:RENDER_CLOCK|RENDER_STALL|ROUTE)\s+", line):
            raise ValueError(
                f"Unsupported diagnostic log format at line {number}; "
                "expected epoch-format logcat")
        if match:
            epoch, pid, kind, payload = match.groups()
            records.append(dict(epoch=float(epoch), pid=pid, kind=kind,
                                data=json.loads(payload), line=number))
    output = []
    for record in records:
        if record["kind"] != "RENDER_STALL":
            continue
        stall = record["data"]
        item = dict(stall=stall, log_line=record["line"],
                    emitted_epoch_s=record["epoch"], pid=record["pid"])
        output.append(item)
        clocks = [r["data"] for r in records
                  if r["pid"] == record["pid"] and r["kind"] == "RENDER_CLOCK"]
        if not clocks:
            item["unresolved"] = "No engine clock anchor for this process"
            continue
        offsets = [c["epoch_seconds"] - (
            c["ticks_before_usec"] + c["ticks_after_usec"]) / 2e6 for c in clocks]
        item["clock_offset_span_ms"] = (max(offsets) - min(offsets)) * 1000
        if item["clock_offset_span_ms"] > 10:
            item["unresolved"] = "Clock discontinuity or mixed sessions; split input"
            continue
        clock = min(clocks, key=lambda c: abs(
            c["ticks_before_usec"] - stall["end_ticks_usec"]))
        if clock["ticks_after_usec"] < clock["ticks_before_usec"]:
            item["unresolved"] = "Invalid clock anchor"
            continue
        end_low = clock["epoch_seconds"] + (
            stall["end_ticks_usec"] - clock["ticks_after_usec"]) / 1e6
        end_high = clock["epoch_seconds"] + (
            stall["end_ticks_usec"] - clock["ticks_before_usec"]) / 1e6
        start_low = end_low - stall["render_wall_ms"] / 1000
        item.update(start_epoch_s=start_low, end_epoch_s=end_high,
                    anchor=clock, end_clock_bracket_ms=(end_high-end_low)*1000)
        routes = [r for r in records
                  if r["pid"] == record["pid"] and r["kind"] == "ROUTE"]
        before = max((r for r in routes if r["epoch"] <= start_low),
                     key=lambda r: r["epoch"], default=None)
        after = min((r for r in routes if r["epoch"] >= end_high),
                    key=lambda r: r["epoch"], default=None)
        item.update(route_before=before, route_after=after)
        if (before is None or after is None or
                start_low - before["epoch"] > 2 or after["epoch"] - end_high > 2):
            item["sample_context"] = "insufficient nearby route samples"
        elif before["data"]["alive"] and after["data"]["alive"]:
            item["sample_context"] = "bracketed by alive samples"
        elif before["data"]["alive"] and not after["data"]["alive"]:
            item["sample_context"] = "overlaps sampled death interval; cause unresolved"
        else:
            item["sample_context"] = "dead or respawning in nearby samples"
    return {
        "scope": "Engine render wall-time correlation only; not acceptance",
        "limitations": [
            "Route samples are discrete; brackets do not prove continuous state.",
            "Anchor brackets exclude logcat precision, clock drift and scheduling error.",
            "No SurfaceFlinger or host monotonic clock alignment is inferred.",
            "Draw/primitive counts and wall time do not identify GPU or shader cause.",
        ],
        "stalls": output,
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
