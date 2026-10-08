import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from android_gfx_stall_summary import summarize


def marker(time, body, tid=4, tgid=3):
    return (f" GLThread- {tid}".replace("- ", "-") +
            f" ( {tgid}) [007] ..... {time:.6f}: tracing_mark_write: {body}")


class GfxStallSummaryTest(unittest.TestCase):
    def test_nested_scopes_sorted_across_cpus_and_process_filter(self):
        rows = [marker(1.1, "B|3|draw"), marker(1.2, "B|3|wait"),
                marker(1.3, "E|3"), marker(1.4, "E|3"),
                marker(1.5, "B|3|submit"), marker(1.6, "E|3"),
                marker(1.25, "B|8|unrelated", tgid=8)]
        result = summarize(reversed(rows), 4, 3, 1, 2)
        self.assertEqual(result["marker_count"], 6)
        self.assertEqual(result["longest_complete_scopes"][0]["name"], "draw")
        self.assertAlmostEqual(result["longest_complete_scopes"][0]["duration_ms"], 300)
        gap = next(r for r in result["largest_marker_gaps"] if r["start"] == 1.2)
        self.assertEqual(gap["open_scopes"], ["draw", "wait"])
        self.assertFalse(result["acceptance_evidence"])

    def test_clipped_boundaries_not_invented_scopes(self):
        rows = [marker(.5, "B|3|clipped"), marker(1.1, "E|3"),
                marker(1.9, "B|3|unfinished"), marker(2.1, "E|3")]
        result = summarize(rows, 4, 3, 1, 2)
        self.assertEqual(result["unmatched_ends"], 1)
        self.assertEqual(result["open_scopes_at_end"], ["unfinished"])
        self.assertEqual(result["longest_complete_scopes"], [])

    def test_invalid_window(self):
        for start, end in [(2, 1), (1, 1), (float("nan"), 2)]:
            with self.assertRaises(ValueError):
                summarize([], 4, 3, start, end)


if __name__ == "__main__":
    unittest.main()
