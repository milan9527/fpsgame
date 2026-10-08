import json
import unittest

from tools.android_render_stall_review import review


def line(epoch, kind, data, pid=10):
    return f"{epoch:.3f} {pid} 11 I godot : ANDROID_{kind} {json.dumps(data)}"


class RenderStallReviewTests(unittest.TestCase):
    def fixture(self, after_alive=True):
        return "\n".join([
            line(100, "ROUTE", {"alive": True}),
            line(101, "ROUTE", {"alive": after_alive}),
            line(105, "RENDER_CLOCK", dict(epoch_seconds=105,
                 ticks_before_usec=5000000, ticks_after_usec=5000002)),
            # Emitted several seconds later than the actual stall.
            line(105, "RENDER_STALL", dict(end_ticks_usec=600000,
                 render_wall_ms=300)),
        ])

    def test_buffered_event_uses_ticks_not_emission_time(self):
        event = review(self.fixture())["stalls"][0]
        self.assertAlmostEqual(event["start_epoch_s"], 100.299998)
        self.assertAlmostEqual(event["end_epoch_s"], 100.6)
        self.assertEqual(event["sample_context"], "bracketed by alive samples")

    def test_death_bracket_remains_uncertain(self):
        event = review(self.fixture(False))["stalls"][0]
        self.assertIn("cause unresolved", event["sample_context"])

    def test_other_process_clock_cannot_be_used(self):
        raw = line(105, "RENDER_CLOCK", dict(epoch_seconds=105,
                   ticks_before_usec=5000000, ticks_after_usec=5000001), pid=12)
        raw += "\n" + line(105, "RENDER_STALL", dict(
            end_ticks_usec=600000, render_wall_ms=300))
        self.assertIn("No engine clock", review(raw)["stalls"][0]["unresolved"])

    def test_wall_clock_jump_rejected(self):
        raw = self.fixture() + "\n" + line(108, "RENDER_CLOCK", dict(
            epoch_seconds=108, ticks_before_usec=6000000, ticks_after_usec=6000001))
        self.assertIn("discontinuity", review(raw)["stalls"][0]["unresolved"])

    def test_sparse_samples_do_not_claim_alive(self):
        raw = self.fixture().replace("101.000 10", "104.000 10")
        self.assertEqual(review(raw)["stalls"][0]["sample_context"],
                         "insufficient nearby route samples")

    def test_threadtime_cannot_silently_hide_stalls(self):
        raw = self.fixture().replace("105.000 10", "10-07 11:26:19.885 10")
        with self.assertRaisesRegex(ValueError, "expected epoch-format"):
            review(raw)

    def test_unrelated_log_lines_are_ignored(self):
        self.assertEqual(review("10-07 11:26:19.885 10 11 I Other: ready")
                         ["stalls"], [])


if __name__ == "__main__":
    unittest.main()
