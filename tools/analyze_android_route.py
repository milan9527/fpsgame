#!/usr/bin/env python3
"""Summarize diagnostic route samples; never produces acceptance frame data."""

import argparse
import json
import math
from pathlib import Path


def analyze(directory):
    decisions = []
    for line in (directory / "route-decisions.jsonl").read_text().splitlines():
        if line.strip():
            decisions.append(json.loads(line))
    samples = []
    seen = set()
    duplicates = 0
    previous = None
    for decision in decisions:
        state = decision["state"]
        epoch = float(state["telemetry_epoch_s"])
        if not math.isfinite(epoch):
            raise ValueError("Non-finite telemetry timestamp")
        if epoch in seen:
            duplicates += 1
            continue
        seen.add(epoch)
        position = [float(state["x"]), float(state["z"])]
        if not all(math.isfinite(v) for v in position):
            raise ValueError("Non-finite route position")
        sample = {
            "cycle": decision["cycle"],
            "telemetry_epoch_s": epoch,
            "position_xz": position,
            "joystick": decision["joystick"],
            "health": state.get("health"),
        }
        if previous is not None:
            elapsed = epoch - previous["telemetry_epoch_s"]
            if elapsed <= 0:
                raise ValueError("Route telemetry timestamps went backwards")
            sample["elapsed_s"] = elapsed
            sample["displacement_m"] = math.dist(position, previous["position_xz"])
        samples.append(sample)
        previous = sample

    gameplay = []
    malformed = []
    decoder = json.JSONDecoder()
    for number, line in enumerate(
        (directory / "final.logcat").read_text(errors="replace").splitlines(), 1
    ):
        if "ANDROID_GAMEPLAY " not in line or " route_json=" not in line:
            continue
        try:
            route, _ = decoder.raw_decode(line.split(" route_json=", 1)[1])
            movement = None
            if " movement_json=" in line:
                movement, _ = decoder.raw_decode(line.split(" movement_json=", 1)[1])
            gameplay.append({
                "source_line": number,
                "log_prefix": line.split("ANDROID_GAMEPLAY ", 1)[0].strip(),
                "route": route,
                "movement": movement,
            })
        except (ValueError, TypeError) as error:
            malformed.append({"source_line": number, "error": str(error)})
    return {
        "source_directory": str(directory),
        "decision_count": len(decisions),
        "duplicate_telemetry_decisions": duplicates,
        "unique_route_samples": samples,
        "gameplay_samples": gameplay,
        "movement_sample_count": sum(s["movement"] is not None for s in gameplay),
        "malformed_gameplay_samples": malformed,
        "limitations": [
            "Sparse gameplay telemetry is not frame presentation evidence.",
            "Displacement spans multiple actions and does not measure continuous speed.",
            "Zero sampled input does not establish a touch failure.",
            "Contacts identify observed collisions, not necessarily the cause of a stall.",
            "Log timestamps are preserved verbatim; no guessed year or timezone alignment.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = analyze(args.directory)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
