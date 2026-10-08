"""Opt-in static rendering experiment; results are not combat acceptance."""
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time

CASES = [
    ("original", .65), ("original", .55), ("original", .45),
    ("flat_ground", .65),
    ("flat_meadow", .65), ("flat_terrain", .65),
    ("flat_road", .65), ("flat_service", .65),
    ("flat_other_custom", .65), ("flat_custom", .65),
    ("hide_ground", .65),
    ("hide_instanced_other", .65), ("hide_individual_other", .65),
    ("hide_other", .65), ("hide_all", .65),
    ("original", .65),
]
EXPECTED = [(view, mode, scale) for view in ("spawn", "road") for mode, scale in CASES]
COMPLETE = "ANDROID_BASELINE_COMPLETE"


def parse_results(logs):
    if re.search(r"FATAL EXCEPTION|SCRIPT ERROR|ANR in org\.ironmeridian\.game", logs):
        raise ValueError("Application error during rendering experiment")
    rows = []
    for line in logs.splitlines():
        if "ANDROID_BASELINE mode=" not in line:
            continue
        values = dict(re.findall(r"(\w+)=([^\s]+)", line))
        row = {key: values[key] for key in ("mode", "view")}
        for key in ("fps", "p95_ms", "draws", "primitives", "scale"):
            row[key] = float(values[key])
            if not math.isfinite(row[key]) or row[key] < 0:
                raise ValueError(f"Invalid {key}: {values[key]}")
        if row["fps"] == 0 or row["p95_ms"] == 0:
            raise ValueError("Empty frame measurement")
        rows.append(row)
    sequence = [(row["view"], row["mode"], round(row["scale"], 2)) for row in rows]
    if sequence != EXPECTED:
        raise ValueError(f"Incomplete or reordered baseline: {len(rows)} of {len(EXPECTED)} cases")
    if COMPLETE not in logs or logs.rfind(COMPLETE) < logs.rfind("ANDROID_BASELINE mode="):
        raise ValueError("Missing final restoration marker")
    return rows


def adb(*args):
    return subprocess.check_output(["adb", *args], timeout=30)


def main():
    out = Path(os.environ["DEVICEFARM_LOG_DIR"])
    out.mkdir(parents=True, exist_ok=True)
    package = "org.ironmeridian.game"
    adb("shell", "am", "force-stop", package)
    adb("logcat", "-c")
    # Drain logcat continuously: repeated -d snapshots can lose early cases
    # when Android's ring buffer wraps during the experiment.
    log_path = out / "render-baseline.logcat"
    log_file = log_path.open("wb")
    try:
        collector = subprocess.Popen(
            ["adb", "logcat"], stdout=log_file, stderr=subprocess.STDOUT)
    except BaseException:
        log_file.close()
        raise
    deadline = time.monotonic() + 360
    try:
        adb("shell", "am", "start", "-W", "-n",
            package + "/com.godot.game.GodotApp",
            "--esa", "command_line_params", "--,--render-baseline")
        while time.monotonic() < deadline:
            logs = log_path.read_text(errors="replace")
            if collector.poll() is not None:
                raise RuntimeError("Logcat collector exited; inspect render-baseline.logcat")
            if COMPLETE in logs:
                break
            if "FATAL EXCEPTION" in logs or "SCRIPT ERROR" in logs:
                raise RuntimeError("Rendering experiment failed; inspect logcat")
            time.sleep(3)
        else:
            raise TimeoutError("Rendering experiment did not finish within 360 seconds")
        rows = parse_results(logs)
        if not adb("shell", "pidof", package).strip():
            raise RuntimeError("Application exited after baseline")
        (out / "render-baseline.json").write_text(json.dumps({
            "scope": "static rendering only; not combat acceptance",
            "samples": rows,
        }, indent=2))
        print(json.dumps({"baseline_cases": len(rows), "restoration_complete": True}), flush=True)
    finally:
        if collector.poll() is None:
            collector.terminate()
            try:
                collector.wait(timeout=10)
            except subprocess.TimeoutExpired:
                collector.kill()
                collector.wait(timeout=10)
        log_file.close()


if __name__ == "__main__":
    main()
