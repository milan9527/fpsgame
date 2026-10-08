"""Optional CPU stack diagnosis; sampled runs are never acceptance evidence."""
from contextlib import contextmanager
import json
import os
import subprocess
import time


@contextmanager
def cpu_sample(out, package):
    if os.environ.get("ANDROID_CPU_SAMPLE") != "1":
        yield
        return
    report = {"acceptance": False, "frequency_hz": 99, "duration_seconds": 35,
              "event": "cpu-clock:u",
              "sample_scope": "User-space stacks only; kernel execution is not sampled",
              "host_start_monotonic_s": time.monotonic(),
              "scope": "Combat plus setup/cleanup; correlate timestamps before attribution"}
    remote = "/data/local/tmp/iron-combat-" + str(time.monotonic_ns()) + ".data"
    process = None
    with (out / "cpu-sample.log").open("wb") as log:
        try:
            version = subprocess.run(
                ["adb", "shell", "simpleperf", "--version"],
                capture_output=True, timeout=10, check=True)
            report["version"] = version.stdout.decode(errors="replace").strip()
            pid = subprocess.run(
                ["adb", "shell", "pidof", package],
                capture_output=True, timeout=10, check=True).stdout.decode().strip()
            if not pid.isdecimal():
                raise RuntimeError("Expected exactly one game PID")
            report["pid"] = int(pid)
            # A finite remote duration survives host interruption without an
            # orphaned, unbounded profiler. FP stacks bound sampling overhead.
            command = ["adb", "shell", "simpleperf", "record", "-p", pid,
                       "-e", report["event"], "-f", "99", "--call-graph", "fp",
                       "--duration", "35", "-o", remote]
            report["command"] = command
            process = subprocess.Popen(command, stdout=log, stderr=log)
        except Exception as exc:
            report["start_error"] = str(exc)
        try:
            yield
        finally:
            report["host_combat_end_monotonic_s"] = time.monotonic()
            if process is not None:
                try:
                    report["returncode"] = process.wait(timeout=45)
                    if process.returncode == 0:
                        local = out / "combat-cpu.data"
                        subprocess.run(["adb", "pull", remote, str(local)],
                                       stdout=log, stderr=log, timeout=30, check=True)
                        report["data_bytes"] = local.stat().st_size
                        with (out / "cpu-sample-report.txt").open("wb") as summary:
                            result = subprocess.run(
                                ["adb", "shell", "simpleperf", "report", "-i", remote],
                                stdout=summary, stderr=log, timeout=30)
                        report["report_returncode"] = result.returncode
                    else:
                        report["sampling_error"] = "See cpu-sample.log"
                except Exception as exc:
                    report["collection_error"] = str(exc)
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=5)
                finally:
                    try:
                        subprocess.run(["adb", "shell", "rm", "-f", remote],
                                       stdout=log, stderr=log, timeout=10, check=True)
                    except Exception as exc:
                        report["cleanup_error"] = str(exc)
            report["host_end_monotonic_s"] = time.monotonic()
            (out / "cpu-sample-status.json").write_text(json.dumps(report, indent=2))
