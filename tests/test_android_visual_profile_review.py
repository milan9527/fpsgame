import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "review", Path(__file__).resolve().parents[1] / "tools/android_visual_profile_review.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReviewTest(unittest.TestCase):
    def run_review(self, frames, **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "raw.jsonl"
            path.write_text("\n".join(json.dumps({
                "message": "visual:profile_frame", "thread_id": 1, "data": frame,
            }) for frame in frames))
            return module.review(path, **kwargs)

    def test_intervals_and_repeated_frame(self):
        frame = [7, 9, "Begin", 0, 0, "Opaque", 2, 1, "End", 302, 5]
        result = self.run_review([frame, frame])
        self.assertEqual(result["unique_frames"], 1)
        self.assertEqual(result["duplicate_frames"], 1)
        self.assertEqual(result["largest_cpu_intervals"][0]["cpu_interval_ms"], 300)
        self.assertEqual(result["largest_cpu_intervals"][0]["from"], "Opaque")
        self.assertFalse(result["acceptance_evidence"])

    def test_invalid_evidence_is_rejected(self):
        for frame in ([7, 3], [7, 4, "Begin", 0, 0, 1],
                      [7, 3, "Begin", float("nan"), 0],
                      [7, 6, "Begin", 2, 0, "End", 1, 0]):
            with self.subTest(frame=frame), self.assertRaises(ValueError):
                self.run_review([frame])

    def test_conflicting_duplicate_rejected(self):
        with self.assertRaises(ValueError):
            self.run_review([[7, 3, "End", 1, 0], [7, 3, "End", 2, 0]])

    def test_combat_filter_excludes_startup_and_deduplicates_summary(self):
        startup = [7, 6, "Begin", 0, 0, "End", 9000, 0]
        combat = [100, 6, "Begin", 2, 0, "End", 302, 0]
        result = self.run_review([startup, combat, combat], first_frame=100, last_frame=100)
        self.assertEqual(result["selected_frames"], 1)
        self.assertEqual(result["unique_frames"], 2)
        stage = result["stage_intervals"][0]
        self.assertEqual(stage["samples"], 1)
        self.assertEqual(stage["total_cpu_interval_ms"], 300)
        self.assertEqual(stage["intervals_over_50ms"], 1)
        self.assertEqual(result["largest_cpu_intervals"][0]["frame"], 100)

    def test_invalid_range_and_invalid_excluded_data_rejected(self):
        for kwargs in ({"first_frame": -1}, {"last_frame": -1},
                       {"first_frame": 5, "last_frame": 4}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                self.run_review([], **kwargs)
        with self.assertRaises(ValueError):
            self.run_review([[7, 6, "Begin", 2, 0, "End", 1, 0]], first_frame=100)


if __name__ == "__main__":
    unittest.main()
