"""Opt-in bounded atrace capture for diagnosis, never acceptance evidence."""
from contextlib import contextmanager
import json
import os
import subprocess
import time


@contextmanager
def system_trace(out):
    if os.environ.get("ANDROID_SYSTEM_TRACE") != "1":
        yield
        return
    profile = os.environ.get("ANDROID_SYSTEM_TRACE_PROFILE", "scheduler")
    buffer_kb = 32768 if profile == "joint" else 16384
    report = {"acceptance": False, "profile": profile, "buffer_kb_per_cpu": buffer_kb,
              "host_start_monotonic_s": time.monotonic(), "started": False}
    attempted = False
    try:
        if profile not in ("scheduler", "render", "joint"):
            raise ValueError("Unknown ANDROID_SYSTEM_TRACE_PROFILE")
        listing = subprocess.run(
            ["adb", "shell", "atrace", "--list_categories"],
            capture_output=True, timeout=15, check=True).stdout.decode(errors="replace")
        report["available_categories"] = listing
        available = {line.split(" - ", 1)[0].strip() for line in listing.splitlines()
                     if " - " in line}
        # r936 lost the first combat stall: gfx/idle traffic overwrote even
        # the short capture. Keep only events needed for running/waiting
        # diagnosis, with a larger (still bounded) per-CPU ring.
        # Joint diagnosis correlates rendering and scheduling in the same stall;
        # use a bounded larger ring, and keep it opt-in due to capture overhead.
        # Coverage and clock alignment still require checking in the raw capture.
        requested = {"render": ("gfx", "sync", "freq"),
                     "scheduler": ("sched", "freq"),
                     "joint": ("sched", "gfx", "sync", "freq")}[profile]
        categories = [name for name in requested
                      if name in available]
        report["categories"] = categories
        report["unavailable_categories"] = [name for name in requested if name not in available]
        required = ("sched", "gfx") if profile == "joint" else (
            ("gfx",) if profile == "render" else ("sched",))
        missing = [name for name in required if name not in categories]
        if missing:
            raise RuntimeError(f"Device does not expose atrace {', '.join(missing)} category")
        attempted = True
        start = subprocess.run(
            ["adb", "shell", "atrace", "--async_start", "-b", str(buffer_kb), *categories],
            capture_output=True, timeout=15, check=True)
        report["start_output"] = start.stdout.decode(errors="replace")
        report["started"] = True
        # ftrace can use a different clock from SurfaceFlinger presentation.
        # Record the selected [clock]; never assume timestamps share an origin.
        try:
            clock = subprocess.run(
                ["adb", "shell",
                 "cat /sys/kernel/tracing/trace_clock 2>/dev/null || "
                 "cat /sys/kernel/debug/tracing/trace_clock"],
                capture_output=True, timeout=10, check=True)
            report["trace_clock"] = clock.stdout.decode(errors="replace").strip()
        except Exception as exc:
            report["trace_clock_error"] = str(exc)
        report["clock_alignment_requires_verification"] = True
    except Exception as exc:
        report["start_error"] = str(exc)
    try:
        yield
    finally:
        if attempted:
            try:
                # Stream compressed ring buffer straight to disk, never into logs.
                with (out / "combat-system.atrace").open("wb") as stream:
                    stop = subprocess.run(
                        ["adb", "exec-out", "atrace", "--async_stop", "-z"],
                        stdout=stream, stderr=subprocess.PIPE, timeout=30, check=True)
                report["stop_stderr"] = stop.stderr.decode(errors="replace")
                report["trace_bytes"] = (out / "combat-system.atrace").stat().st_size
                report["stopped"] = True
            except Exception as exc:
                report["stop_error"] = str(exc)
        report["host_end_monotonic_s"] = time.monotonic()
        (out / "system-trace-status.json").write_text(json.dumps(report, indent=2))
