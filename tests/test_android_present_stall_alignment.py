import json
import unittest

from tools.android_present_stall_alignment import align


def command(epoch_ms=100500, mono_ns=500000000):
    return {"stderr": "ANDROID_TOUCH_CLOCK " + json.dumps({
        "stage": "start", "epoch_ms": epoch_ms,
        "monotonic_before_ns": mono_ns, "monotonic_after_ns": mono_ns+100})}


class AlignmentTests(unittest.TestCase):
    def test_buffered_log_is_correlated_by_engine_ticks(self):
        raw = '\n'.join([
            '105.000 10 11 I godot : ANDROID_RENDER_CLOCK ' + json.dumps({
                "epoch_seconds": 105, "ticks_before_usec": 5000000,
                "ticks_after_usec": 5000002}),
            '105.000 10 11 I godot : ANDROID_RENDER_STALL ' + json.dumps({
                "end_ticks_usec": 600000, "render_wall_ms": 300})])
        result = align([300000000, 633000000], [command()], raw)
        gap = result["gaps_over_50ms"][0]
        self.assertEqual(gap["start_epoch_ns_bounds"], [100299999900, 100301000000])
        match = gap["possible_engine_overlaps"][0]
        self.assertEqual(match["log_line"], 2)
        self.assertEqual(match["engine_anchor_age_ms"], 4400)

    def test_old_injector_does_not_get_synthetic_offset(self):
        gap = align([1, 333000001], [{}], "")["gaps_over_50ms"][0]
        self.assertIn("No device anchor", gap["unresolved"])

    def test_distant_anchor_rejected(self):
        gap = align([9000000000, 9333000000], [command()], "")["gaps_over_50ms"][0]
        self.assertIn("unresolved", gap)

    def test_wall_clock_step_rejected(self):
        gap = align([300000000, 633000000],
                    [command(), command(101500)], "")["gaps_over_50ms"][0]
        self.assertIn("disagree", gap["unresolved"])

    def test_invalid_presentation_input_rejected(self):
        for values in ([1, 1], [2, 1], [1.0, 333000000], [True, 333000000]):
            with self.assertRaises(ValueError):
                align(values, [], "")

    def test_short_frames_not_reported_as_stalls(self):
        self.assertEqual(align([1, 16666668], [], "")["gaps_over_50ms"], [])


if __name__ == "__main__":
    unittest.main()
