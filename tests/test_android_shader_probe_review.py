"""Synthetic parser checks only; these fixtures are not device evidence."""
import unittest
import json

from tools.android_shader_probe_review import review


def line(operation="save_cache", start=10000, end=20000, duration=10000):
    return (
        f"1791425000.123 31614 31660 I godot : IRON_SHADER_PROBE "
        f"operation={operation} start_us={start} end_us={end} "
        f"duration_us={duration}"
    )


class ShaderProbeReviewTest(unittest.TestCase):
    def test_bind_total_preserves_nested_compile_without_double_counting(self):
        result = review("\n".join([
            line("compile_specialization", 10000, 90000, 80000),
            line("bind_shader_total", 1000, 101000, 100000),
        ]))
        self.assertEqual(result["operations"]["bind_shader_total"],
                         {"count": 1, "max_duration_us": 100000})
        self.assertEqual(len(result["calls"]), 2)
        self.assertNotIn("total_duration_us", result)
        self.assertFalse(result["acceptance"])

    def test_nested_calls_remain_separate_without_sum(self):
        result = review(line() + "\n" + line(
            "compile_specialization", 1000, 101000, 100000))
        self.assertEqual(len(result["calls"]), 2)
        self.assertEqual(result["calls"][0]["pid"], 31614)
        self.assertEqual(result["calls"][0]["tid"], 31660)
        self.assertEqual(result["operations"]["compile_specialization"],
                         {"count": 1, "max_duration_us": 100000})
        self.assertFalse(result["acceptance"])
        self.assertNotIn("total_duration_us", result)

    def test_empty_capture_does_not_invent_measurements(self):
        result = review("unrelated log line")
        self.assertEqual(result["calls"], [])
        self.assertIsNone(result["operations"]["load_cache"]["max_duration_us"])

    def test_shader_identity_and_legacy_records(self):
        suffix = (" shader=SceneShaderGLES3 variant=2 specialization=18446744073709551615"
                  " vertex_sha256=" + "a" * 64 + " fragment_sha256=" + "b" * 64)
        result = review(line("compile_specialization") + suffix + "\n" + line())
        identity = result["calls"][0]["identity"]
        self.assertEqual(identity["specialization"], 2**64 - 1)
        self.assertEqual(identity["variant"], 2)
        self.assertEqual(identity["vertex_sha256"], "a" * 64)
        self.assertNotIn("identity", result["calls"][1])
        for invalid in (line() + suffix,
                        line("compile_specialization") + suffix[:-1],
                        line("compile_specialization") + suffix.replace("variant=2", "variant=-1")):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                review(invalid)

    def test_reject_invalid_or_truncated_records(self):
        for text in (line(duration=9999), line(start=30000),
                     line(end=17000, duration=7000),
                     line().replace("save_cache", "unknown"),
                     line().split(" end_us=")[0],
                     "IRON_SHADER_PROBE operation=save_cache"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                review(text)

    def test_tick_overlap_ignores_delivery_time_and_other_processes(self):
        # Delayed render logging has no clock anchor. Tick correlation still works.
        stall = "1791425010.0 31614 31660 I godot : ANDROID_RENDER_STALL " + json.dumps(
            {"end_ticks_usec": 70000, "render_wall_ms": 60})
        result = review("\n".join([
            line(), line().replace("31614", "99999"),
            line(start=80000, end=90000), stall]))
        self.assertEqual(result["render_tick_overlaps"][0][
            "overlapping_shader_log_lines"], [1])
        self.assertFalse(result["acceptance"])

    def test_invalid_render_interval_is_rejected(self):
        for wall in (-1, float("nan"), 100):
            text = "1791425010.0 31614 31660 I godot : ANDROID_RENDER_STALL " + json.dumps(
                {"end_ticks_usec": 70000, "render_wall_ms": wall})
            with self.subTest(wall=wall), self.assertRaises(ValueError):
                review(text)


if __name__ == "__main__":
    unittest.main()
