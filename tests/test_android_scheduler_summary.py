"""Scheduler accounting tests, not performance acceptance."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from android_scheduler_summary import summarize


def line(t, event, body, tid=10, tgid=10):
    return f" worker-{tid} ( {tgid}) [001] d..2. {t:.6f}: {event}: {body}"


def switch(t, prev, nxt, state="S"):
    return line(t, "sched_switch",
                f"prev_pid={prev} prev_state={state} ==> next_pid={nxt}")


class SchedulerTests(unittest.TestCase):
    def test_core_accounting_across_migration_and_window(self):
        lines = [switch(1, 0, 10), switch(3, 10, 0, "R"),
                 switch(4, 0, 10).replace("[001]", "[003]"),
                 switch(6, 10, 0).replace("[001]", "[003]")]
        row = summarize(lambda: iter(reversed(lines)), 10, (2, 5))["threads"][0]
        self.assertEqual(row["running_by_cpu_ms"], {"1": 1000, "3": 1000})
        self.assertEqual(row["cpu_boundary_mismatches"], 0)
        self.assertEqual(sum(row["running_by_cpu_ms"].values()),
                         row["intervals"]["running"]["total_ms"])

    def test_missing_migration_boundary_does_not_assign_core(self):
        lines = [switch(1, 0, 10),
                 switch(3, 10, 0).replace("[001]", "[003]")]
        row = summarize(lambda: iter(lines), 10)["threads"][0]
        self.assertEqual(row["running_by_cpu_ms"], {})
        self.assertEqual(row["cpu_boundary_mismatches"], 1)

    def test_window_clips_intervals_using_events_outside_window(self):
        lines = [switch(1, 0, 10), switch(3, 10, 0),
                 line(5, "sched_wakeup", "pid=10"), switch(7, 0, 10)]
        report = summarize(lambda: iter(reversed(lines)), 10, (2, 6))
        stats = report["threads"][0]["intervals"]
        self.assertEqual(stats["running"]["total_ms"], 1000)
        self.assertEqual(stats["sleeping"]["total_ms"], 2000)
        self.assertEqual(stats["runnable"]["total_ms"], 1000)
        self.assertFalse(report["clock_alignment_verified"])
        self.assertEqual(report["window_trace_s"], [2, 6])

    def test_window_does_not_invent_unobserved_boundaries(self):
        lines = [switch(1, 10, 0), switch(4, 0, 10)]
        stats = summarize(lambda: iter(lines), 10, (2, 5))["threads"][0]["intervals"]
        self.assertEqual(stats["off_cpu_unsplit"]["total_ms"], 2000)
        self.assertNotIn("running", stats)
        self.assertEqual(summarize(lambda: iter(lines), 10, (5, 6))
                         ["threads"][0]["intervals"], {})

    def test_invalid_window(self):
        for window in [(2, 1), (1, 1), (float("nan"), 2), (1, float("inf"))]:
            with self.assertRaises(ValueError):
                summarize(lambda: iter([]), 10, window)

    def test_sleep_runnable_preemption_and_duplicate_wake(self):
        lines = [
            switch(1, 0, 10), switch(2, 10, 0),
            line(3, "sched_wakeup", "pid=10"),
            line(3.5, "sched_wakeup", "pid=10"),
            switch(4, 0, 10), switch(5, 10, 0, "R+"),
            switch(6, 0, 10), switch(7, 10, 0),
        ]
        report = summarize(lambda: iter(reversed(lines)), 10)
        row = report["threads"][0]
        self.assertEqual(row["intervals"]["running"]["total_ms"], 3000)
        self.assertEqual(row["intervals"]["sleeping"]["total_ms"], 1000)
        self.assertEqual(row["intervals"]["runnable"]["total_ms"], 2000)
        self.assertEqual(row["inconsistent_transitions"], 0)

    def test_missing_wake_is_not_claimed_as_sleep(self):
        lines = [switch(1, 10, 0), switch(4, 0, 10)]
        row = summarize(lambda: iter(lines), 10)["threads"][0]
        self.assertEqual(row["intervals"]["off_cpu_unsplit"]["total_ms"], 3000)
        self.assertNotIn("running", row["intervals"])
        self.assertNotIn("sleeping", row["intervals"])

    def test_membership_uses_tgid_not_name(self):
        lines = [line(1, "sched_wakeup", "pid=99", tid=99, tgid=99)]
        self.assertEqual(summarize(lambda: iter(lines), 10)["threads"], [])

    def test_switch_from_idle_with_unknown_tgid(self):
        lines = [
            line(1, "sched_switch", "prev_pid=0 prev_state=R ==> next_pid=10",
                 tid=0, tgid="-----"),
            switch(2, 10, 0),
        ]
        row = summarize(lambda: iter(lines), 10)["threads"][0]
        self.assertEqual(row["intervals"]["running"]["total_ms"], 1000)


if __name__ == "__main__":
    unittest.main()
