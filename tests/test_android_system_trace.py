"""Trace lifecycle tests; synthetic data is not performance evidence."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess

spec = importlib.util.spec_from_file_location(
    "system_trace", Path(__file__).resolve().parents[1] / "tools/android_system_trace.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TraceTests(unittest.TestCase):
    def test_joint_capture_has_both_categories_and_bounded_larger_ring(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.dict(os.environ, {"ANDROID_SYSTEM_TRACE": "1",
                                        "ANDROID_SYSTEM_TRACE_PROFILE": "joint"}), \
                patch.object(module.subprocess, "run", side_effect=[
                    CompletedProcess([], 0, b"sched - Scheduling\ngfx - Graphics\nfreq - Frequency\n"),
                    CompletedProcess([], 0, b""),
                    CompletedProcess([], 0, b"[boot]\n"),
                    CompletedProcess([], 0, stderr=b"")]) as run:
            with module.system_trace(Path(folder)):
                pass
            self.assertEqual(run.call_args_list[1].args[0],
                             ["adb", "shell", "atrace", "--async_start",
                              "-b", "32768", "sched", "gfx", "freq"])
            report = json.loads((Path(folder) / "system-trace-status.json").read_text())
            self.assertEqual(report["buffer_kb_per_cpu"], 32768)
            self.assertEqual(report["unavailable_categories"], ["sync"])
            self.assertTrue(report["stopped"])
            self.assertFalse(report["acceptance"])

    def test_joint_rejects_either_missing_required_category(self):
        for available, missing in ((b"sched - Scheduling\n", "gfx"),
                                   (b"gfx - Graphics\n", "sched")):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as folder, \
                    patch.dict(os.environ, {"ANDROID_SYSTEM_TRACE": "1",
                                            "ANDROID_SYSTEM_TRACE_PROFILE": "joint"}), \
                    patch.object(module.subprocess, "run",
                                 return_value=CompletedProcess([], 0, available)) as run:
                with module.system_trace(Path(folder)):
                    pass
                report = json.loads((Path(folder) / "system-trace-status.json").read_text())
                self.assertIn(missing, report["start_error"])
                self.assertFalse(report["started"])
                run.assert_called_once()

    def test_render_trace_excludes_sched_and_records_missing_optional_sync(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.dict(os.environ, {"ANDROID_SYSTEM_TRACE": "1",
                                        "ANDROID_SYSTEM_TRACE_PROFILE": "render"}), \
                patch.object(module.subprocess, "run", side_effect=[
                    CompletedProcess([], 0, b"sched - Scheduling\ngfx - Graphics\nfreq - Frequency\n"),
                    CompletedProcess([], 0, b""),
                    CompletedProcess([], 0, b"[boot]\n"),
                    CompletedProcess([], 0, stderr=b"")]) as run:
            with module.system_trace(Path(folder)):
                pass
            self.assertEqual(run.call_args_list[1].args[0],
                             ["adb", "shell", "atrace", "--async_start",
                              "-b", "16384", "gfx", "freq"])
            report = json.loads((Path(folder) / "system-trace-status.json").read_text())
            self.assertEqual(report["unavailable_categories"], ["sync"])
            self.assertEqual(report["profile"], "render")
            self.assertTrue(report["stopped"])

    def test_disabled_does_not_touch_adb(self):
        with patch.dict(os.environ, {"ANDROID_SYSTEM_TRACE": "0"}), \
                patch.object(module.subprocess, "run") as run:
            with module.system_trace(Path("/unused")):
                pass
            run.assert_not_called()

    def test_gameplay_failure_still_stops_trace(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.dict(os.environ, {"ANDROID_SYSTEM_TRACE": "1"}), \
                patch.object(module.subprocess, "run", side_effect=[
                    CompletedProcess([], 0, b"sched - CPU Scheduling\nfreq - Frequency\nidle - Idle\ngfx - Graphics\n"),
                    CompletedProcess([], 0, b""),
                    CompletedProcess([], 0, b"local global [boot] mono\n"),
                    CompletedProcess([], 0, stderr=b"")]) as run:
            with self.assertRaisesRegex(RuntimeError, "death"):
                with module.system_trace(Path(folder)):
                    raise RuntimeError("death")
            self.assertIn("--async_stop", run.call_args.args[0])
            self.assertEqual(run.call_args_list[1].args[0],
                             ["adb", "shell", "atrace", "--async_start",
                              "-b", "16384", "sched", "freq"])
            report = json.loads((Path(folder) / "system-trace-status.json").read_text())
            self.assertTrue(report["stopped"])
            self.assertFalse(report["acceptance"])
            self.assertIn("[boot]", report["trace_clock"])
            self.assertTrue(report["clock_alignment_requires_verification"])

    def test_clock_read_failure_does_not_prevent_trace_cleanup(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.dict(os.environ, {"ANDROID_SYSTEM_TRACE": "1"}), \
                patch.object(module.subprocess, "run", side_effect=[
                    CompletedProcess([], 0, b"sched - CPU Scheduling\n"),
                    CompletedProcess([], 0, b""),
                    RuntimeError("trace_clock permission denied"),
                    CompletedProcess([], 0, stderr=b"")]) as run:
            with module.system_trace(Path(folder)):
                pass
            report = json.loads((Path(folder) / "system-trace-status.json").read_text())
            self.assertTrue(report["started"])
            self.assertTrue(report["stopped"])
            self.assertIn("permission denied", report["trace_clock_error"])
            self.assertIn("--async_stop", run.call_args.args[0])

    def test_unsupported_device_records_reason_and_allows_gameplay(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.dict(os.environ, {"ANDROID_SYSTEM_TRACE": "1"}), \
                patch.object(module.subprocess, "run", return_value=
                             CompletedProcess([], 0, b"gfx - Graphics\n")) as run:
            with module.system_trace(Path(folder)):
                pass
            self.assertEqual(run.call_count, 1)
            report = json.loads((Path(folder) / "system-trace-status.json").read_text())
            self.assertIn("sched", report["start_error"])
