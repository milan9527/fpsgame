"""Collect SurfaceFlinger actual-present timestamps; never substitute engine FPS.

Run alongside gameplay after warmup, with the exact SurfaceView layer name.
Raw polls are retained even when the device denies access or continuity fails.
This capability must be probed on the target device before acceptance use.
"""
import argparse
import json
from pathlib import Path
import subprocess
import shlex
import time
import re


def surface_layers(listing, package):
    """Unwrap Android's debug description, retaining the layer's #sequence."""
    layers = []
    for line in listing.splitlines():
        layer = line
        if line.startswith("RequestedLayerState{") and line.endswith("}"):
            layer = line[len("RequestedLayerState{"):-1]
            layer = re.split(r" (?:parentId|relativeParentId|z)=", layer, maxsplit=1)[0]
        if package in layer and "SurfaceView" in layer and layer not in layers:
            layers.append(layer)
    return layers


def latency_command(layer):
    # adb shell reparses its arguments remotely; SurfaceView names contain
    # spaces and parentheses and must remain one shell argument.
    return ["adb", "shell", shlex.join(
        ["dumpsys", "SurfaceFlinger", "--latency", layer])]


def probe(package, output, seconds=10, ready=None, stop=None):
    """Capability probe during gameplay; not a full acceptance run."""
    output.mkdir(parents=True, exist_ok=False)
    report = {"valid": False, "scope": f"{seconds}-second capability probe"}
    try:
        listing = subprocess.run(
            ["adb", "shell", "dumpsys", "SurfaceFlinger", "--list"],
            capture_output=True, text=True, timeout=10)
        (output / "layers.json").write_text(json.dumps({
            "stdout": listing.stdout, "stderr": listing.stderr,
            "returncode": listing.returncode}))
        listing.check_returncode()
        candidates = surface_layers(listing.stdout, package)
        report["candidate_layers"] = candidates
        active = []
        for index, layer in enumerate(candidates):
            if stop is not None and stop.is_set():
                raise ValueError("Diagnostic collection stopped")
            samples = []
            for poll in range(2):
                response = subprocess.run(latency_command(layer),
                                          capture_output=True, text=True, timeout=10)
                (output / f"candidate-{index}-{poll}.json").write_text(json.dumps({
                    "layer": layer, "stdout": response.stdout,
                    "stderr": response.stderr, "returncode": response.returncode}))
                if response.returncode:
                    break
                values = actual_present_times(response.stdout)
                samples.append(values)
                if poll == 0:
                    time.sleep(.2)
            if (len(samples) == 2 and all(samples)
                    and samples[1][-1] > samples[0][-1]):
                active.append(layer)
        report["advancing_layers"] = active
        if len(active) != 1:
            raise ValueError(f"Expected one advancing game SurfaceView, found {len(active)}")
        collect(active[0], output / "intervals", seconds, .5, ready=ready, stop=stop)
        report.update(valid=True, layer=active[0])
    except Exception as exc:
        # Capability failure is evidence for the Perfetto fallback, not a
        # reason to discard the independent gameplay diagnostics.
        report["error"] = str(exc)
    (output / "probe.json").write_text(json.dumps(report, indent=2))
    return report


def actual_present_times(text):
    """SurfaceFlinger --latency columns: desired, actual, frame-ready (ns)."""
    values = []
    for line in text.splitlines()[1:]:
        fields = line.split()
        if len(fields) != 3:
            continue
        try:
            desired, actual, ready = map(int, fields)
        except ValueError:
            continue
        if 0 < actual < 2**63 - 1:
            values.append(actual)
    if values != sorted(set(values)):
        raise ValueError("Actual-present timestamps are duplicated or out of order")
    return values


class Timeline:
    def __init__(self):
        self.timestamps = []

    def append(self, values):
        if not values:
            raise ValueError("No actual-present timestamps; unsupported/empty layer")
        if not self.timestamps:
            self.timestamps.extend(values)
            return
        last = self.timestamps[-1]
        # Require overlap rather than silently interpreting lost ring entries
        # as one long frame or joining timestamps from a recreated surface.
        if last not in values:
            raise ValueError("SurfaceFlinger ring continuity lost")
        self.timestamps.extend(values[values.index(last) + 1:])


def collect(layer, output, seconds, poll_seconds, ready=None, stop=None):
    output.mkdir(parents=True, exist_ok=False)
    timeline = Timeline()
    start = time.monotonic()
    report = {"source": "SurfaceFlinger --latency actualPresentTime",
              "layer": layer, "requested_seconds": seconds, "valid": False,
              "host_start_monotonic_s": start,
              "clock_note": "Poll elapsed times use this host origin; actual-present "
                            "timestamps use the device clock. Do not subtract across clocks."}
    try:
        index = 0
        while True:
            if stop is not None and stop.is_set():
                raise ValueError("Diagnostic collection stopped before duration target")
            before = time.monotonic()
            process = subprocess.run(
                latency_command(layer),
                capture_output=True, text=True, timeout=10)
            (output / f"poll-{index:05d}.json").write_text(json.dumps({
                "start_elapsed_s": before - start,
                "end_elapsed_s": time.monotonic() - start,
                "stdout": process.stdout, "stderr": process.stderr,
                "returncode": process.returncode}))
            process.check_returncode()
            values = actual_present_times(process.stdout)
            # Seed only the newest timestamp: the pre-warmup ring is excluded.
            timeline.append(values if index else values[-1:])
            if index == 0:
                report["seed_host_monotonic_s"] = time.monotonic()
                if ready is not None:
                    ready.set()
            index += 1
            duration = (timeline.timestamps[-1] - timeline.timestamps[0]) / 1e9
            if duration >= seconds:
                break
            if time.monotonic() - start > seconds + 30:
                raise ValueError("Layer stopped presenting before duration target")
            delay = max(0, poll_seconds - (time.monotonic() - before))
            if stop is None:
                time.sleep(delay)
            else:
                stop.wait(delay)
        intervals = [(b - a) / 1e6 for a, b in
                     zip(timeline.timestamps, timeline.timestamps[1:])]
        (output / "frame-times.json").write_text(json.dumps({"frame_times_ms": intervals}))
        report.update(valid=True, duration_s=duration, frames=len(intervals))
    except Exception as exc:
        report["error"] = str(exc)
        raise
    finally:
        (output / "timestamps.json").write_text(json.dumps(timeline.timestamps))
        (output / "collection.json").write_text(json.dumps(report, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layer", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--seconds", type=float, default=305)
    parser.add_argument("--poll-seconds", type=float, default=.5)
    args = parser.parse_args()
    if args.seconds <= 0 or not 0 < args.poll_seconds <= 1:
        parser.error("seconds must be positive; poll-seconds must be in (0, 1]")
    collect(args.layer, args.output, args.seconds, args.poll_seconds)
