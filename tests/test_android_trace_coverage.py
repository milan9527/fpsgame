"""Synthetic parser checks; not device performance evidence."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zlib

spec = importlib.util.spec_from_file_location(
    "coverage", Path(__file__).resolve().parents[1] / "tools/android_trace_coverage.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CoverageTests(unittest.TestCase):
    def test_overwrite_and_explicit_loss_are_reported(self):
        report = module.coverage([
            "# entries-in-buffer/entries-written: 10/100 #P:1",
            "CPU:0 [LOST 7 EVENTS]",
            "CPU:0 [LOST 2 EVENTS]",
            "worker-1 [000] d..2 1.000: sched_switch:"])
        self.assertEqual(report["buffer_entries"]["not_retained"], 90)
        self.assertEqual(report["explicit_lost_events"], 9)
        self.assertTrue(report["loss_detected"])
        # CPU endpoints cannot establish loss-free data.
        self.assertTrue(report["all_cpus_observed"])
        self.assertFalse(report["clock_alignment_verified"])

    def test_missing_header_does_not_invent_entry_counts(self):
        report = module.coverage([])
        self.assertIsNone(report["buffer_entries"])
        self.assertFalse(report["clock_alignment_verified"])

    def test_missing_cpu_does_not_claim_common_window(self):
        report = module.coverage(["#P:2", "worker-1 [000] d..2 1.000: sched_switch:"])
        self.assertFalse(report["all_cpus_observed"])
        self.assertIsNone(report["common_observed_window"])

    def test_common_window_is_intersection_and_not_clock_proof(self):
        report = module.coverage([
            "#P:2",
            "worker-1 [000] d..2 1.000: sched_switch:",
            "worker-1 [000] d..2 4.000: sched_switch:",
            "worker-2 [001] d..2 2.000: sched_switch:",
            "worker-2 [001] d..2 3.000: sched_switch:"])
        self.assertEqual(report["common_observed_window"], {"start_s": 2., "end_s": 3.})
        self.assertFalse(report["clock_alignment_verified"])

    def test_stream_limit_and_truncation(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "trace"
            body = b"short line\n" * 20000
            payload = zlib.compress(body)
            path.write_bytes(b"TRACE:\n" + payload)
            self.assertEqual(len(list(module.trace_lines(path))), 20000)
            with self.assertRaisesRegex(ValueError, "byte limit"):
                list(module.trace_lines(path, max_bytes=1000))
            path.write_bytes(b"TRACE:\n" + payload[:-3])
            with self.assertRaisesRegex(ValueError, "Truncated"):
                list(module.trace_lines(path))
