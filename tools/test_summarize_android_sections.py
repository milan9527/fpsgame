import tempfile
import unittest
from pathlib import Path

from summarize_android_sections import summarize


class SectionSummaryTests(unittest.TestCase):
    def test_overlapping_captures_preserve_distinct_windows(self):
        first = "09-29 18:48:37.474 22787 22829 I godot : "
        second = "09-29 18:48:42.489 22787 22829 I godot : "
        record = "ANDROID_SECTION name=actors mean_ms=1.0 peak_ms=2.0 count=10\n"
        slow = "ANDROID_SECTION name=actors mean_ms=3.0 peak_ms=5.0 count=20\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.log"
            path.write_text(first + record + first + record + second + slow)
            report = summarize(path)
        self.assertEqual(report["duplicate_records_removed"], 1)
        self.assertEqual(report["sections"]["actors"]["count"], 30)
        self.assertAlmostEqual(
            report["sections"]["actors"]["weighted_mean_ms_approx"], 7 / 3
        )
        self.assertEqual(report["sections"]["actors"]["peak_ms"], 5)
        self.assertEqual(
            [w["line"] for w in report["sections"]["actors"]["windows"]], [1, 3]
        )

    def test_same_values_at_distinct_times_or_without_timestamp_are_retained(self):
        record = "ANDROID_SECTION name=slide mean_ms=1 peak_ms=2 count=5\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.log"
            path.write_text(
                "09-29 18:48:37.474 1 2 I godot : " + record
                + "09-29 18:48:38.474 1 2 I godot : " + record
                + record + record
            )
            report = summarize(path)
        self.assertEqual(report["duplicate_records_removed"], 0)
        self.assertEqual(report["sections"]["slide"]["count"], 20)


if __name__ == "__main__":
    unittest.main()
