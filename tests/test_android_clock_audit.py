"""Clock safety checks; synthetic fixtures are not device performance evidence."""
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from android_clock_audit import audit, trace_sync_markers


def marker(stage, base, offset=500):
    return "ANDROID_TOUCH_CLOCK " + json.dumps({
        "stage": stage, "monotonic_before_ns": base, "epoch_ms": 1000,
        "monotonic_after_ns": base + 10,
        "boot_monotonic_before_ns": base + 20,
        "boottime_ns": base + 25 + offset,
        "boot_monotonic_after_ns": base + 30,
    })


class ClockAuditTest(unittest.TestCase):
    def test_trace_sync_units_and_epoch_precision(self):
        prefix = " atrace-10 ( 10) [003] ..... 802.932854: tracing_mark_write: "
        report = trace_sync_markers([
            prefix + "trace_event_clock_sync: realtime_ts=1791374060307",
            prefix + "trace_event_clock_sync: parent_ts=802.932861",
        ])
        first, second = report["markers"]
        self.assertEqual(first["sample_timestamp_ns"], 1791374060307000000)
        self.assertEqual(first["trace_timestamp_ns"], 802932854000)
        self.assertEqual(second["sample_minus_trace_ns"], 7000)
        self.assertFalse(report["clock_alignment_verified"])

    def test_trace_sync_ignores_unrelated_or_malformed_lines(self):
        report = trace_sync_markers([
            "trace_event_clock_sync: realtime_ts=123",
            " atrace-10 [003] ..... 1.000000: sched_switch: realtime_ts=123",
            " atrace-10 [003] ..... 1.000000: tracing_mark_write: "
            "trace_event_clock_sync: realtime_ts=nan",
        ])
        self.assertEqual(report["markers"], [])

    def run_audit(self, end_offset=500, clock="local [boot] mono", stderr=None):
        record = {"cycle": 0, "stderr": stderr if stderr is not None else
                  marker("start", 100) + "\n" +
                  marker("injection_end", 1000, end_offset)}
        return audit({"trace_clock": clock, "started": True, "stopped": True},
                     [record])

    def test_consistent_samples_are_not_global_alignment(self):
        report = self.run_audit()
        self.assertTrue(report["all_sample_offsets_consistent"])
        self.assertEqual(report["cycles"][0]["sample_offset_intersection_ns"],
                         [495, 505])
        self.assertFalse(report["clock_alignment_verified"])
        self.assertFalse(report["acceptance"])

    def test_offset_change_fails_closed(self):
        self.assertFalse(self.run_audit(600)["all_sample_offsets_consistent"])

    def test_unknown_or_different_selected_clock(self):
        for clock in ("boot mono", "[mono] boot", "[boot] [mono]", ""):
            self.assertFalse(self.run_audit(clock=clock)["all_sample_offsets_consistent"])

    def test_missing_duplicate_and_reversed_endpoints(self):
        for raw in ("", marker("start", 100),
                    marker("start", 100) + "\n" + marker("start", 1000),
                    marker("start", 1000) + "\n" + marker("injection_end", 100)):
            self.assertFalse(self.run_audit(stderr=raw)["all_sample_offsets_consistent"])

    def test_empty_records_not_success(self):
        self.assertFalse(audit({}, [])["all_sample_offsets_consistent"])

    def test_old_markers_without_boot_measurement_fail_closed(self):
        lines = []
        for stage, base in (("start", 100), ("injection_end", 1000)):
            lines.append("ANDROID_TOUCH_CLOCK " + json.dumps({
                "stage": stage, "monotonic_before_ns": base,
                "monotonic_after_ns": base + 10, "epoch_ms": 1000}))
        self.assertFalse(self.run_audit(stderr="\n".join(lines))[
            "all_sample_offsets_consistent"])

    def test_incomplete_trace_capture_fails_closed(self):
        record = {"stderr": marker("start", 100) + "\n" +
                  marker("injection_end", 1000)}
        result = audit({"trace_clock": "[boot]", "started": True}, [record])
        self.assertFalse(result["all_sample_offsets_consistent"])


if __name__ == "__main__":
    unittest.main()
