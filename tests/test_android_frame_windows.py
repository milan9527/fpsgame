"""Synthetic tests, never device frame evidence."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "windows", Path(__file__).resolve().parents[1] /
    "tools/profile_android_frame_windows.py")
windows = importlib.util.module_from_spec(spec)
spec.loader.exec_module(windows)


class FrameWindowsTest(unittest.TestCase):
    def test_exact_boundary_without_seconds_accumulation_drift(self):
        report = windows.profile([16] * 3750)
        self.assertEqual([w["frames"] for w in report["windows"]], [1875, 1875])
        self.assertEqual([w["end_s"] for w in report["windows"]], [30, 60])

    def test_late_slowdown_and_frame_conservation(self):
        report = windows.profile([10] * 3000 + [25] * 1200)
        self.assertEqual([w["fps"] for w in report["windows"]], [100, 40])
        self.assertEqual(sum(w["frames"] for w in report["windows"]), 4200)

    def test_long_stall_is_not_split_or_dropped(self):
        report = windows.profile([100, 65000, 10])
        self.assertEqual([w["frames"] for w in report["windows"]], [2, 1])
        self.assertEqual(report["windows"][0]["max_ms"], 65000)
        self.assertAlmostEqual(sum(w["duration_s"] for w in report["windows"]),
                               report["overall"]["duration_s"])
        self.assertEqual(report["windows"][1]["first_frame"], 2)
        self.assertIsNone(report["first_last_boundary_windows"])

    def test_short_fast_tail_does_not_mask_sustained_slowdown(self):
        report = windows.profile([10] * 3000 + [25] * 1200 + [1] * 100)
        self.assertEqual([w["reached_boundary"] for w in report["windows"]],
                         [True, True, False])
        self.assertEqual(report["first_last_boundary_windows"], {
            "first_window_index": 0, "last_window_index": 1,
            "fps_delta": -60, "p95_ms_delta": 15, "p99_ms_delta": 15,
            "over_50ms_ratio_delta": 0,
        })

    def test_short_capture_has_no_time_comparison(self):
        report = windows.profile([16] * 100)
        self.assertIsNone(report["first_last_boundary_windows"])
        self.assertFalse(report["windows"][0]["reached_boundary"])

    def test_invalid_measurements_rejected(self):
        for values in ([], [True], [0], [-1], [float("nan")], [float("inf")]):
            with self.assertRaises(ValueError):
                windows.profile(values)
        for duration in (0, -1, float("nan"), float("inf")):
            with self.assertRaises(ValueError):
                windows.profile([16], duration)

    def test_stalls_retain_original_indices_and_device_relative_times(self):
        report = windows.profile([10, 50, 60, 65000, 10])
        self.assertEqual(report["stalls_over_50ms"], [
            {"frame_index": 2, "start_s": .06, "end_s": .12, "interval_ms": 60},
            {"frame_index": 3, "start_s": .12, "end_s": 65.12, "interval_ms": 65000},
        ])
        self.assertAlmostEqual(
            len(report["stalls_over_50ms"]) / report["overall"]["frames"],
            report["overall"]["over_50ms_ratio"])


if __name__ == "__main__":
    unittest.main()
