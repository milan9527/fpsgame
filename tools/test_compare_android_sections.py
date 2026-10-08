import tempfile
import unittest
from pathlib import Path

from compare_android_sections import compare


class ComparisonTests(unittest.TestCase):
    def compare_logs(self, before, after):
        with tempfile.TemporaryDirectory() as directory:
            a, b = Path(directory) / "before", Path(directory) / "after"
            a.write_text(before)
            b.write_text(after)
            return compare(a, b)

    def test_weighted_windows_and_missing_sections(self):
        report = self.compare_logs(
            "ANDROID_SECTION name=cover mean_ms=1 peak_ms=3 count=10\n"
            "ANDROID_SECTION name=cover mean_ms=3 peak_ms=5 count=30\n"
            "ANDROID_SECTION name=before_only mean_ms=4 peak_ms=4 count=1\n",
            "ANDROID_SECTION name=cover mean_ms=2 peak_ms=4 count=20\n"
            "ANDROID_SECTION name=after_only mean_ms=1 peak_ms=1 count=1\n",
        )
        cover = report["sections"]["cover"]
        self.assertEqual(cover["weighted_mean_ms_approx_delta"], -0.5)
        self.assertEqual(cover["peak_ms_delta"], -1)
        self.assertEqual(cover["before"]["count"], 40)
        self.assertEqual(cover["after"]["count"], 20)
        for name in ("before_only", "after_only"):
            self.assertIsNone(report["sections"][name]["peak_ms_delta"])
        self.assertIsNone(report["sections"]["before_only"]["after"])
        self.assertIsNone(report["sections"]["after_only"]["before"])
        self.assertNotEqual(
            report["sources"]["before"]["source_sha256"],
            report["sources"]["after"]["source_sha256"],
        )

    def test_zero_samples_do_not_imply_zero_mean(self):
        report = self.compare_logs(
            "ANDROID_SECTION name=cover mean_ms=0 peak_ms=0 count=0\n",
            "ANDROID_SECTION name=cover mean_ms=2 peak_ms=2 count=1\n",
        )
        self.assertIsNone(report["sections"]["cover"]["weighted_mean_ms_approx_delta"])

    def test_empty_capture_rejected(self):
        with self.assertRaisesRegex(ValueError, "both captures"):
            self.compare_logs("", "ANDROID_SECTION name=x mean_ms=1 peak_ms=1 count=1\n")


if __name__ == "__main__":
    unittest.main()
