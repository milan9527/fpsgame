import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from android_touch_continuity import analyze


def cycle(number, start):
    # Actual receipts intentionally differ from planned offsets.
    return {
        "cycle": number, "success": True,
        "events": [[0, 0, [[1, 1]]], [100, 1, [[1, 1]]],
                   [132, 0, [[9, 9]]], [282, 1, [[10, 9]]]],
        "stdout": "\n".join(f"{i} {start + offset} {action}" for i, (offset, action)
                            in enumerate([(0, 0), (110, 1), (150, 0), (310, 1)])),
    }


class ContinuityTests(unittest.TestCase):
    def test_actual_receipts_include_scan_and_transport_gap(self):
        result = analyze([cycle(0, 1000), cycle(1, 1700)])
        self.assertEqual(result["span_ms"], 1010)
        self.assertEqual(result["stick_held_ms"], 220)
        self.assertEqual(result["stick_released_ms"], 790)
        self.assertEqual(result["cycles"][1]["gap_after_previous_stick_up_ms"], 590)
        self.assertFalse(result["acceptance"])

    def test_reject_invalid_or_incomplete_evidence(self):
        original = cycle(0, 1000)
        for field, value in [
            ("success", False),
            ("stdout", "\n".join(original["stdout"].splitlines()[:-1])),
            ("stdout", original["stdout"].replace("1 1110 1", "1 999 1")),
            ("stdout", original["stdout"].replace("1 1110 1", "1 1110 2")),
        ]:
            damaged = copy.deepcopy(original)
            damaged[field] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                analyze([damaged])
        for records in ([], [original, cycle(2, 1700)], [original, cycle(1, 1200)]):
            with self.assertRaises(ValueError):
                analyze(records)

    def test_reject_changed_stick_pointer(self):
        record = cycle(0, 1000)
        record["events"][1][2] = [[2, 2]]
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            analyze([record])


if __name__ == "__main__":
    unittest.main()
