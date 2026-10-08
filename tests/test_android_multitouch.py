"""Pointer lifecycle checks; these are not Android delivery/performance evidence."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import subprocess
import tempfile
import json

spec = importlib.util.spec_from_file_location(
    "touch", Path(__file__).resolve().parents[1] / "tools/android_multitouch.py")
touch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(touch)


class TouchTest(unittest.TestCase):
    def test_input_completion_boundary_retains_fresh_sample_and_raw_fallback(self):
        observation = ("ANDROID_LOOK_END_CLOCK=1791449151.223215306\n"
                       "sample at 1791449151.117\n")
        anchors = [
            {"stage": "start", "monotonic_before_ns": 1019521960000,
             "monotonic_after_ns": 1019521970000, "epoch_ms": 1791449149375},
            {"stage": "injection_end", "monotonic_before_ns": 1021200990000,
             "monotonic_after_ns": 1021201000000, "epoch_ms": 1791449151054},
        ]
        updated = touch.input_completion_observation(observation, anchors)
        self.assertIn("ANDROID_LOOK_END_CLOCK=1791449151.055000000", updated)
        self.assertIn("sample at 1791449151.117", updated)
        # Missing/duplicate anchors, wall-clock jumps, reversed clocks and a
        # shell clock older than injection must retain the conservative barrier.
        for invalid in (
                [], anchors + [anchors[-1]],
                [anchors[0], dict(anchors[1], epoch_ms=1791449150054)],
                [anchors[0], dict(anchors[1], monotonic_before_ns=1)],
                [anchors[0], dict(anchors[1], epoch_ms=1791449151254)]):
            self.assertEqual(touch.input_completion_observation(
                observation, invalid), observation)

    def test_clock_anchor_preserves_integer_precision_and_quantization(self):
        epoch = 1791075923446
        anchor = {"stage": "start", "monotonic_before_ns": 123456789012345,
                  "epoch_ms": epoch, "monotonic_after_ns": 123456789012678}
        result = touch.clock_anchors(
            "unrelated timing\nANDROID_TOUCH_CLOCK " + json.dumps(anchor))[0]
        self.assertEqual(result["epoch_minus_monotonic_min_ns"],
                         epoch * 1000000 - 123456789012678)
        self.assertEqual(result["epoch_minus_monotonic_max_ns"]
                         - result["epoch_minus_monotonic_min_ns"], 1000333)
        self.assertEqual(touch.clock_anchors("old injector"), [])

    def test_clock_anchor_rejects_reversed_or_noninteger_clocks(self):
        for before, after in ((12, 11), (1.5, 12), (True, 12), (-1, 12)):
            with self.assertRaises(ValueError):
                touch.clock_anchors("ANDROID_TOUCH_CLOCK " + json.dumps({
                    "monotonic_before_ns": before, "monotonic_after_ns": after,
                    "epoch_ms": 1791075923446}))

    def test_boot_clock_anchor_bounds_preserve_suspend_offset(self):
        anchor = {"monotonic_before_ns": 100000000000001,
                  "monotonic_after_ns": 100000000000021, "epoch_ms": 1791075923446,
                  "boot_monotonic_before_ns": 100000000000030,
                  "boottime_ns": 100005000000040,
                  "boot_monotonic_after_ns": 100000000000050}
        result = touch.clock_anchors("ANDROID_TOUCH_CLOCK " + json.dumps(anchor))[0]
        self.assertEqual(result["boot_minus_monotonic_min_ns"], 4999999990)
        self.assertEqual(result["boot_minus_monotonic_max_ns"], 5000000010)
        old = {key: value for key, value in anchor.items()
               if key not in ("boot_monotonic_before_ns", "boottime_ns",
                              "boot_monotonic_after_ns")}
        self.assertNotIn("boot_minus_monotonic_min_ns", touch.clock_anchors(
            "ANDROID_TOUCH_CLOCK " + json.dumps(old))[0])

    def test_boot_clock_anchor_rejects_partial_or_invalid_readings(self):
        base = {"monotonic_before_ns": 10, "monotonic_after_ns": 20,
                "epoch_ms": 1791075923446, "boot_monotonic_before_ns": 30,
                "boottime_ns": 50, "boot_monotonic_after_ns": 40}
        for key, value in (("boot_monotonic_before_ns", 19),
                           ("boot_monotonic_after_ns", 29),
                           ("boottime_ns", 29), ("boottime_ns", True),
                           ("boottime_ns", 50.5), ("boottime_ns", None)):
            invalid = dict(base, **{key: value})
            with self.assertRaises(ValueError):
                touch.clock_anchors("ANDROID_TOUCH_CLOCK " + json.dumps(invalid))
        for key in ("boot_monotonic_before_ns", "boottime_ns", "boot_monotonic_after_ns"):
            invalid = dict(base)
            del invalid[key]
            with self.assertRaises(ValueError):
                touch.clock_anchors("ANDROID_TOUCH_CLOCK " + json.dumps(invalid))

    def test_supply_route_movement_is_bounded_by_corner_and_recovery(self):
        def release(**options):
            events = touch.combat_events((1440, 900), (220, 650), 0,
                                        route_feedback=True, **options)
            return next(event[0] for event in events if event[1] == 1)
        for supply in ("healing", "reloading"):
            for distance, duration in ((8.5, 250), (10, 400), (11.38, 538),
                                       (12, 600), (13.5, 750), (30, 750)):
                actual = release(**{supply: True}, route_distance_m=distance)
                self.assertEqual(actual, duration)
                self.assertLessEqual(actual / 100, distance - 6)
            for distance in (None, 6, -1, float("nan"), float("inf")):
                self.assertEqual(release(**{supply: True},
                                         route_distance_m=distance), 250)
            self.assertEqual(release(**{supply: True}, route_distance_m=30,
                                     recovery=True), 250)
        # Newly submitted supply actions keep their immediate timing.
        for options in ({"heal": True}, {"reload": True}):
            self.assertEqual(release(**options), release(**options, route_distance_m=30))

    def test_grenade_evasion_moves_without_aim_or_fire_and_refreshes_look(self):
        for distance, duration in ((2, 250), (4.837642, 483), (12, 750)):
            events = touch.combat_events(
                (1440, 900), (80, 650), 0, route_feedback=True,
                route_distance_m=distance, evading=True)
            self.assertTrue(all(len(points) == 1 for _, _, points in events))
            self.assertEqual(next(t for t, action, _ in events if action == 1),
                             duration)
            self.assertEqual(events[-1][0], duration + 182)
        normal = touch.combat_events(
            (1440, 900), (80, 650), 1, route_feedback=True,
            route_distance_m=4.837642)
        self.assertEqual(sum(action == 261 for _, action, _ in normal), 3)

    def test_long_combat_leg_moves_longer_without_changing_combat_or_look(self):
        options = dict(route_feedback=True)
        baseline = touch.combat_events((1440, 900), (220, 650), 0, **options)
        for distance in (None, 15, -1, float("nan"), float("inf")):
            self.assertEqual(touch.combat_events(
                (1440, 900), (220, 650), 0, route_distance_m=distance,
                **options), baseline)
        for distance, extra_ms in ((16, 26), (18, 226), (20, 426), (30, 500)):
            longer = touch.combat_events(
                (1440, 900), (220, 650), 0, route_distance_m=distance,
                **options)
            self.assertEqual(longer[0], baseline[0])
            self.assertEqual([(t - extra_ms, a, p) for t, a, p in longer[1:]],
                             baseline[1:])
            release_ms = next(t for t, a, p in longer if a == 1)
            self.assertEqual(release_ms, 974 + extra_ms)
            # At the diagnostic upper speed estimate, stop at least 6m
            # short of the waypoint before turning and requesting fresh yaw.
            self.assertLessEqual(release_ms / 100, distance - 6)
            self.assertEqual(touch.combat_events(
                (1440, 900), (220, 650), 0, route_distance_m=distance,
                recovery=True, **options), baseline)

    def test_exposed_corner_clears_before_resuming_combat(self):
        for distance, duration in ((2.813022, 281), (1.326538, 250)):
            events = touch.combat_events(
                (1440, 900), (80, 650), 0, route_feedback=True,
                route_distance_m=distance)
            self.assertTrue(all(len(points) == 1 for _, _, points in events))
            self.assertEqual(next(t for t, a, _ in events if a == 1), duration)
            self.assertEqual(events[-1][0], duration + 182)
        for options in (dict(route_distance_m=3.01, route_feedback=True),
                        dict(route_distance_m=2.8),
                        dict(route_distance_m=2.8, route_feedback=True,
                             recovery=True)):
            events = touch.combat_events((1440, 900), (80, 650), 1, **options)
            self.assertEqual(sum(a == 261 for _, a, _ in events),
                             3 if options.get("route_feedback") else 4)
        events = touch.combat_events(
            (1440, 900), (80, 650), 0, route_feedback=True,
            route_distance_m=2.8, heal=True)
        self.assertIn((1010, 775), [p for _, _, pts in events for p in pts])

    def test_building_route_feedback_keeps_combat_and_supply_touches(self):
        normal = touch.combat_events((1440, 900), (210, 570), 0)
        feedback = touch.combat_events(
            (1440, 900), (210, 570), 0, route_feedback=True)
        self.assertEqual(feedback[-1][0], 1156)
        self.assertEqual(normal[0], feedback[0])
        # Aim/fire/aim remain simultaneous with movement, with unchanged holds.
        self.assertEqual([(t - 1750, a, p) for t, a, p in normal[1:7]],
                         feedback[1:7])
        for action in ("heal", "reload"):
            normal_supply = touch.combat_events(
                (1440, 900), (210, 570), 0, **{action: True})
            feedback_supply = touch.combat_events(
                (1440, 900), (210, 570), 0, route_feedback=True, **{action: True})
            self.assertEqual(normal_supply[:3], feedback_supply[:3])
            self.assertEqual(normal_supply[-1][0] - 150, feedback_supply[-1][0])

    def test_route_look_releases_stale_direction_before_changing_yaw(self):
        for options in ({}, {"heal": True}, {"reload": True},
                        {"healing": True}, {"reloading": True}, {"recovery": True}):
            events = touch.combat_events(
                (1440, 900), (210, 570), 0, route_feedback=True, **options)
            release = next(i for i, e in enumerate(events) if e[1] == 1)
            look = events[release + 1:]
            self.assertEqual(events[release][2], [(210, 570)])
            self.assertEqual(look[0][1:], (0, [touch.combat_look_points((1440, 900))[0]]))
            self.assertEqual(look[-1][1:], (1, [touch.combat_look_points((1440, 900))[1]]))
            self.assertEqual(look[-1][0] - look[0][0], 150)
            self.assertTrue(all(len(e[2]) == 1 for e in look))
            self.assertEqual(len([e for e in look if e[1] == 2]), 9)

    def test_recovery_observes_sooner_without_shortening_combat(self):
        normal = touch.combat_events((1440, 900), (210, 570), 0)
        recovery = touch.combat_events((1440, 900), (210, 570), 0, recovery=True)
        self.assertEqual(normal[-1][0], 3056)
        self.assertEqual(recovery[-1][0], 1306)
        self.assertEqual(normal[0], recovery[0])
        self.assertEqual([(t - 1750, a, p) for t, a, p in normal[1:]],
                         recovery[1:])
        # Healing cannot be shortened: the game must finish before retrying.
        self.assertEqual(
            touch.combat_events((1440, 900), (210, 570), 0, heal=True),
            touch.combat_events((1440, 900), (210, 570), 0, heal=True,
                                recovery=True))

    def test_stationary_holds_keep_duration_without_move_injections(self):
        events = touch.combat_events((1440, 900), (210, 570), 0)
        down = None
        durations = []
        moves = []
        for offset, action, points in events:
            if action & 255 == 5:
                down = offset
                moves = []
            elif action == 2:
                moves.append(points[1])
            elif action & 255 == 6:
                durations.append(offset - down)
                if len(durations) < 4:  # Aim, fire, aim.
                    self.assertEqual(moves, [])
                else:
                    self.assertEqual(len(moves), 18)
                    self.assertGreater(len(set(moves)), 1)
        self.assertEqual(durations, [64, 500, 64, 300])
        self.assertEqual(events[-1][0], 3056)

    def test_reload_starts_promptly_and_returns_moving_route_feedback(self):
        for recovery in (False, True):
            events = touch.combat_events((1440, 900), (210, 570), 0,
                                         reload=True, recovery=recovery)
            downs = [event for event in events if event[1] & 255 == 5]
            self.assertEqual(len(downs), 2)  # Reload and look, no firing.
            self.assertEqual(downs[0][2][1], (1170, 775))
            self.assertLess(downs[0][0], 100)
            self.assertLess(events[-1][0], 1500)
            self.assertTrue(all(event[2][0] == (210, 570) for event in events))
            self.assertEqual(events[-1][1], 1)

    def test_active_reload_observes_soon_without_repeating_supply_touch(self):
        events = touch.combat_events((1440, 900), (210, 570), 0,
                                     reloading=True)
        downs = [event for event in events if event[1] & 255 == 5]
        self.assertEqual(len(downs), 1)  # Look only, no fire or supply toggle.
        self.assertEqual(downs[0][2][1], touch.combat_look_points((1440, 900))[0])
        self.assertLess(events[-1][0], 1200)
        self.assertTrue(all(event[2][0] == (210, 570) for event in events))
        self.assertEqual(events[-1][1], 1)

    def test_heal_returns_route_feedback_without_fire_or_reload(self):
        events = touch.combat_events((1440, 900), (210, 570), 0,
                                     reload=True, heal=True)
        downs = [event for event in events if event[1] & 255 == 5]
        self.assertEqual(len(downs), 2)  # Heal and look only.
        self.assertEqual(downs[0][2][1], (1010, 775))
        self.assertLess(downs[0][0], 100)
        heal_up = next(event for event in events if event[1] & 255 == 6)
        self.assertGreater(events[-1][0] - heal_up[0], 750)
        self.assertLess(events[-1][0], 1500)
        self.assertTrue(all(event[2][0] == (210, 570) for event in events))
        self.assertEqual(events[-1][1], 1)
        pending = touch.combat_events((1440, 900), (190, 580), 1, healing=True)
        self.assertLess(pending[-1][0], 1500)
        self.assertEqual(sum(event[1] & 255 == 5 for event in pending), 1)

    def test_post_touch_observation_uses_same_transport_and_requires_receipts(self):
        events = touch.combat_events((1440, 900), (210, 570), 0)
        receipts = "".join(f"{i} {1000 + e[0]} {e[1]}\n"
                           for i, e in enumerate(events))
        for prefix, suffix, valid in (
                (receipts, "\nANDROID_TOUCH_OBSERVATION\nroute\n", True),
                (receipts, "", False),
                (receipts, "\nANDROID_TOUCH_OBSERVATION\n", False),
                ("", "\nANDROID_TOUCH_OBSERVATION\nroute\n", False)):
            with tempfile.TemporaryDirectory() as directory:
                result = subprocess.CompletedProcess([], 0, prefix + suffix, "")
                with patch.object(touch.subprocess, "run", return_value=result) as run:
                    if valid:
                        self.assertEqual(touch.run_combat(
                            (1440, 900), (210, 570), 0, directory,
                            observation_command="echo route"), "route\n")
                    else:
                        with self.assertRaises(RuntimeError):
                            touch.run_combat((1440, 900), (210, 570), 0, directory,
                                             observation_command="echo route")
                    run.assert_called_once()
                    command = run.call_args.args[0][2]
                # Execute captured composition without Android, checking that
                # injection errors prevent the observation being emitted.
                base = touch.injection_command(touch.encode(events))
                for exit_code in (0, 7):
                    shell = command.replace(base, f"(exit {exit_code})", 1)
                    actual = subprocess.run(["sh", "-c", shell], capture_output=True)
                    self.assertEqual(actual.returncode, exit_code)
                    self.assertEqual(b"route\n" in actual.stdout, exit_code == 0)
                    if exit_code == 0:
                        self.assertRegex(
                            actual.stdout,
                            rb"ANDROID_TOUCH_OBSERVATION\nANDROID_LOOK_END_CLOCK=\d+\.\d{9}\nroute\n")
                    else:
                        self.assertNotIn(b"ANDROID_LOOK_END_CLOCK=", actual.stdout)

    def test_continuous_primary_and_balanced_secondary(self):
        for size in ((1440, 900), (2400, 1080), (1080, 2400)):
            for healing in (False, True):
                for reload in (False, True):
                    events = touch.combat_events(size, (210, 570), 0, healing, reload)
                    active = []
                    last = -1
                    stick = events[0][2][0]
                    actions = []
                    for offset, action, points in events:
                        self.assertGreaterEqual(offset, last)
                        self.assertEqual(points[0], stick)
                        last = offset
                        masked = action & 255
                        if masked == 0:
                            self.assertEqual(active, [])
                            active = [0]
                        elif masked == 5:
                            self.assertEqual(active, [0])
                            self.assertEqual(action >> 8, 1)
                            active = [0, 1]
                        self.assertEqual(len(points), len(active))
                        if masked == 6:
                            self.assertEqual(active, [0, 1])
                            self.assertEqual(action >> 8, 1)
                            active = [0]
                        elif masked == 1:
                            self.assertEqual(active, [0])
                            active = []
                        actions.append(masked)
                    self.assertEqual(active, [])
                    self.assertEqual(actions.count(5), 2 if reload else (1 if healing else 4))
                    self.assertLess(last, 10000)
                    self.assertEqual(len(touch.encode(events).splitlines()), len(events))

    def test_scan_does_not_cancel_or_cross_buttons(self):
        for size in ((1440, 900), (2400, 1080)):
            for cycle in (0, 1):
                events = touch.combat_events(size, (180, 550), cycle)
                start, end = touch.combat_look_points(size)
                moves = [e[2][1] for e in events if e[1] == 2]
                self.assertTrue(all(start[0] < p[0] < end[0] for p in moves))
                self.assertTrue(all(p[1] == start[1] for p in moves))
                self.assertEqual(events[-2][2][1], end)
                # In the game's 1440x900 layout, buttons on the right
                # start at y=430; keep the entire scan above them.
                scale = min(size[0] / 1440, size[1] / 900)
                self.assertLess(end[1], (size[1] - 900 * scale) / 2 + 430 * scale)

    def test_receipts_and_failure_are_recorded(self):
        events = touch.combat_events((1440, 900), (210, 570), 0)
        receipts = "".join(f"{i} {1000 + e[0]} {e[1]}\n"
                           for i, e in enumerate(events))
        for stdout, returncode, success in ((receipts, 0, True),
                                            (receipts[:-10], 0, False),
                                            ("", 1, False)):
            with tempfile.TemporaryDirectory() as directory:
                result = subprocess.CompletedProcess([], returncode, stdout, "")
                with patch.object(touch.subprocess, "run", return_value=result) as run:
                    if success:
                        touch.run_combat((1440, 900), (210, 570), 0, directory)
                    else:
                        with self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
                            touch.run_combat((1440, 900), (210, 570), 0, directory)
                    self.assertEqual(
                        (Path(directory) / "multitouch-cycle-0.txt").read_text(),
                        touch.encode(events))
                    self.assertEqual(run.call_args.args[0],
                                     ["adb", "shell", touch.injection_command(touch.encode(events))])
                    self.assertEqual(run.call_count, 1)
                record = json.loads((Path(directory) / "multitouch-commands.jsonl").read_text())
                self.assertEqual(record["success"], success)
                if success:
                    self.assertEqual(record["device_first_event_uptime_ms"], 1000)
                    self.assertEqual(record["device_last_event_uptime_ms"], 1000 + events[-1][0])
                    self.assertEqual(record["device_event_span_ms"], events[-1][0])

    def test_invalid_device_event_clock_fails_closed(self):
        events = touch.combat_events((1440, 900), (210, 570), 0)
        for bad_time in ("bad", "-1", "999"):
            receipts = "".join(
                f"{i} {bad_time if i == 1 else 1000 + e[0]} {e[1]}\n"
                for i, e in enumerate(events))
            with tempfile.TemporaryDirectory() as directory:
                result = subprocess.CompletedProcess([], 0, receipts, "")
                with patch.object(touch.subprocess, "run", return_value=result):
                    with self.assertRaises((RuntimeError, ValueError)):
                        touch.run_combat((1440, 900), (210, 570), 0, directory)
                record = json.loads((Path(directory) / "multitouch-commands.jsonl").read_text())
                self.assertFalse(record["success"])

    def test_shell_transport_failure_is_recorded(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.CompletedProcess([], 1, "", "device offline")
            with patch.object(touch.subprocess, "run", return_value=result) as run:
                with self.assertRaises(subprocess.CalledProcessError):
                    touch.run_combat((1440, 900), (210, 570), 0, directory)
                self.assertEqual(run.call_count, 1)
            record = json.loads((Path(directory) / "multitouch-commands.jsonl").read_text())
            self.assertFalse(record["success"])
            self.assertEqual(record["returncode"], 1)

    def test_literal_payload_and_failed_write_gate(self):
        # Execute the actual shell syntax locally with a harmless stand-in for
        # app_process; this checks newlines and metacharacters, not Android input.
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "events.txt"
            receipt = Path(directory) / "injected.txt"
            payload = "0 0 1 200 300\n' $HOME `false` $(false) %s\n"
            command = touch.injection_command(payload).replace(
                "/data/local/tmp/iron-touch-events.txt", str(target)).replace(
                "CLASSPATH=/data/local/tmp/iron-multitouch.jar "
                "app_process /system/bin MultiTouch", f"cat > {receipt}")
            completed = subprocess.run(["sh", "-c", command], check=True,
                                       capture_output=True, text=True)
            stages = completed.stderr.splitlines()
            self.assertEqual(len(stages), 2)
            self.assertTrue(stages[0].startswith("ANDROID_TOUCH_STAGE inject_start boottime_s="))
            self.assertTrue(stages[1].startswith("ANDROID_TOUCH_STAGE inject_end boottime_s="))
            self.assertGreaterEqual(float(stages[1].split("=")[1]),
                                    float(stages[0].split("=")[1]))
            self.assertEqual(receipt.read_text(), payload)
            receipt.unlink()
            target.unlink()
            target.mkdir()
            failed = subprocess.run(["sh", "-c", command], capture_output=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertFalse(receipt.exists())
            self.assertNotIn(b"ANDROID_TOUCH_STAGE", failed.stderr)

    def test_stage_names_are_bounded(self):
        with self.assertRaises(ValueError):
            touch.device_stage_command("$(false)")


if __name__ == "__main__":
    unittest.main()
