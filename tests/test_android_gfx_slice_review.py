import unittest

from tools.android_gfx_slice_review import review


def event(tid, stamp, payload):
    return f" Render-Thread-{tid} (  100) [002] .... {stamp:.6f}: tracing_mark_write: {payload}"


class SliceReviewTests(unittest.TestCase):
    def test_nested_interleaved_threads_same_process(self):
        report = review([
            event(1, 1, "B|100|outer"), event(2, 1.001, "B|100|other"),
            event(1, 1.002, "B|100|inner"), event(2, 1.003, "E|100"),
            event(1, 1.004, "E"), event(1, 1.010, "E"),
        ])
        self.assertEqual(report["completed_slices"], 3)
        rows = {row["name"]: row for row in report["longest_slices"]}
        self.assertAlmostEqual(rows["outer"]["wall_ms"], 10)
        self.assertAlmostEqual(rows["inner"]["wall_ms"], 2)
        self.assertAlmostEqual(rows["other"]["wall_ms"], 2)
        self.assertFalse(report["acceptance"])

    def test_loss_discards_open_spans(self):
        report = review([event(1, 1, "B|100|invalid"),
                         "CPU:2 [LOST 5 EVENTS]", event(1, 2, "E")])
        self.assertEqual(report["completed_slices"], 0)
        self.assertEqual(report["explicit_lost_events"], 5)
        self.assertEqual(report["discarded_begins"], 1)
        self.assertEqual(report["unmatched_ends"], 1)

    def test_reverse_time_and_async_not_paired(self):
        report = review([event(1, 2, "B|100|invalid"), event(1, 1, "E"),
                         event(1, 3, "S|100|async|1"),
                         event(1, 4, "F|100|async|1")])
        self.assertEqual(report["completed_slices"], 0)
        self.assertEqual(report["discarded_begins"], 1)
        self.assertEqual(report["ignored_markers"], 2)

    def test_bounded_longest_and_open_begin(self):
        lines = []
        for i in range(5):
            lines += [event(1, i * 2, "B|100|swap"),
                      event(1, i * 2 + 0.1 * i, "E")]
        lines += [event(1, 20, "B|100|unfinished")]
        report = review(lines, limit=2)
        self.assertEqual(report["completed_slices"], 5)
        self.assertEqual(len(report["longest_slices"]), 2)
        self.assertAlmostEqual(report["longest_slices"][0]["wall_ms"], 400)
        self.assertEqual(report["open_begins"], 1)

    def test_pid_filter_uses_payload_process_not_thread(self):
        report = review([event(1, 1, "B|100|app"), event(1, 2, "E"),
                         event(100, 3, "B|200|other"), event(100, 4, "E")],
                        pid_filter=100)
        self.assertEqual(report["completed_slices"], 1)
        self.assertEqual(report["longest_slices"][0]["name"], "app")

    def test_window_preserves_enclosing_and_nested_pairs(self):
        report = review([
            event(1, 1, "B|100|outer"),
            event(1, 2, "B|100|before"), event(1, 3, "E"),
            event(1, 4, "B|100|inner"),
            event(2, 4, "B|100|other"), event(2, 6, "E"),
            event(1, 6, "E"),
            event(1, 7, "B|100|after"), event(1, 8, "E"),
            event(1, 9, "E"),
        ], tid_filter=1, window_start=3, window_end=7)
        rows = {row["name"]: row for row in report["longest_slices"]}
        self.assertEqual(set(rows), {"outer", "inner"})
        self.assertAlmostEqual(rows["outer"]["wall_ms"], 8000)
        self.assertEqual(report["unmatched_ends"], 0)
        self.assertEqual(report["open_begins"], 0)

    def test_invalid_windows(self):
        for start, end in [(2, 1), (1, 1), (float("nan"), 2),
                           (1, float("inf"))]:
            with self.subTest(start=start, end=end), self.assertRaises(ValueError):
                review([], window_start=start, window_end=end)


if __name__ == "__main__":
    unittest.main()
