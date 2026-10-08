"""Audit released-stick time from real Android MotionEvent receipts.

This is input continuity evidence, never presentation or acceptance evidence.
Only the route-feedback stream (stick released before a one-pointer look) is
supported. Refuse ambiguous or incomplete receipts instead of estimating.
"""
import argparse
import hashlib
import json
from pathlib import Path


def analyze(records):
    cycles = []
    previous_end = None
    previous_release = None
    for record in records:
        if not record.get("success"):
            raise ValueError("Unsuccessful injection")
        events = record["events"]
        receipt_text = record["stdout"].split("\nANDROID_TOUCH_OBSERVATION\n", 1)[0]
        receipts = [[int(value) for value in line.split()]
                    for line in receipt_text.splitlines() if line.strip()]
        if len(receipts) != len(events) or not events:
            raise ValueError("Incomplete receipts")
        for index, (event, receipt) in enumerate(zip(events, receipts)):
            if len(receipt) != 3 or receipt[0] != index or receipt[2] != event[1]:
                raise ValueError("Receipt does not match planned event")
        times = [receipt[1] for receipt in receipts]
        if times[0] < 0 or any(b < a for a, b in zip(times, times[1:])):
            raise ValueError("Nonmonotonic event timestamps")
        ups = [i for i, event in enumerate(events) if event[1] == 1]
        downs = [i for i, event in enumerate(events) if event[1] == 0]
        if (len(ups) != 2 or downs != [0, ups[0] + 1]
                or ups[-1] != len(events) - 1
                or any(event[1] != 2 for event in events[downs[1] + 1:ups[-1]])):
            raise ValueError("Expected released-stick route-feedback stream")
        pointer_count = 1
        stick = events[0][2][0]
        for event in events[1:ups[0]]:
            action = event[1]
            if action == 261 and pointer_count == 1:
                pointer_count = 2
            elif action == 262 and pointer_count == 2:
                pass
            elif action != 2:
                raise ValueError("Unsupported stick pointer transition")
            if len(event[2]) != pointer_count or event[2][0] != stick:
                raise ValueError("Stick pointer changed during hold")
            if action == 262:
                pointer_count = 1
        if (pointer_count != 1 or events[ups[0]][2] != [stick]
                or any(len(event[2]) != 1 for event in events[downs[1]:])):
            raise ValueError("Ambiguous released-stick pointer stream")
        if previous_end is not None and times[0] < previous_end:
            raise ValueError("Overlapping injection cycles")
        if cycles and record["cycle"] != cycles[-1]["cycle"] + 1:
            raise ValueError("Missing or reordered cycle")
        release = times[ups[0]]
        cycles.append({
            "cycle": record["cycle"],
            "first_down_uptime_ms": times[0],
            "stick_up_uptime_ms": release,
            "last_up_uptime_ms": times[-1],
            "stick_held_ms": release - times[0],
            "released_scan_ms": times[-1] - release,
            "gap_after_previous_last_up_ms": (
                None if previous_end is None else times[0] - previous_end),
            "gap_after_previous_stick_up_ms": (
                None if previous_release is None else times[0] - previous_release),
        })
        previous_end, previous_release = times[-1], release
    if not cycles:
        raise ValueError("No injection cycles")
    span = cycles[-1]["last_up_uptime_ms"] - cycles[0]["first_down_uptime_ms"]
    if span <= 0:
        raise ValueError("Empty observation span")
    held = sum(cycle["stick_held_ms"] for cycle in cycles)
    return {
        "acceptance": False,
        "scope": "MotionEvent timestamps; stick command state, not actual player motion or frame times",
        "span_ms": span,
        "stick_held_ms": held,
        "stick_released_ms": span - held,
        "stick_released_fraction": (span - held) / span,
        "cycles": cycles,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("commands", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    raw = args.commands.read_bytes()
    result = analyze([json.loads(line) for line in raw.splitlines() if line.strip()])
    result["source"] = str(args.commands)
    result["source_sha256"] = hashlib.sha256(raw).hexdigest()
    args.output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
