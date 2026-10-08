"""Synthetic orchestration checks, never device performance evidence."""
import importlib.util
import os
from pathlib import Path
import sys
import unittest
import json
import math
import subprocess
from contextlib import nullcontext
from tempfile import TemporaryDirectory
from unittest.mock import MagicMock, patch

TOOLS = Path(__file__).resolve().parents[1] / "tools"
with patch.dict(os.environ, {"DEVICEFARM_LOG_DIR": "/tmp/walkthrough-unit-test"}):
    sys.path.insert(0, str(TOOLS))
    try:
        spec = importlib.util.spec_from_file_location(
            "walkthrough", TOOLS / "android_native_walkthrough.py")
        walkthrough = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(walkthrough)
    finally:
        sys.path.pop(0)


class TimingTest(unittest.TestCase):
    @staticmethod
    def compatibility_xml():
        return (b'<hierarchy><node package="android" text="debuggable app 16 KB '
                b'ELF alignment check failed libgodot_android.so"/>'
                b'<node package="android" resource-id="android:id/button1" '
                b'text="OK" enabled="true" clickable="true" '
                b'bounds="[100,200][300,280]"/></hierarchy>')

    def test_debug_warning_selects_native_ok_only(self):
        xml = self.compatibility_xml()
        self.assertEqual(walkthrough.debug_compatibility_button(xml), (200, 240))
        for before, after in ((b'package="android"', b'package="com.browser"'),
                              (b'debuggable app', b'release app'),
                              (b'libgodot_android.so', b'other.so')):
            self.assertIsNone(walkthrough.debug_compatibility_button(
                xml.replace(before, after)))
        for before, after in ((b'text="OK"', b'text="Learn more"'),
                              (b'[100,200][300,280]', b'[100,200][100,200]'),
                              (b'clickable="true"', b'clickable="false"')):
            with self.assertRaises(RuntimeError):
                walkthrough.debug_compatibility_button(xml.replace(before, after))

    def test_debug_warning_saves_evidence_and_verifies_dismissal(self):
        with TemporaryDirectory() as directory, \
                patch.object(walkthrough, "OUT", Path(directory)), \
                patch.object(walkthrough, "capture"), \
                patch.object(walkthrough.time, "sleep"), \
                patch.object(walkthrough, "adb", side_effect=[
                    b"", self.compatibility_xml(), b"", b"", b"<hierarchy/>"]) as adb:
            walkthrough.dismiss_debug_compatibility_warning()
            adb.assert_any_call("shell", "input", "tap", "200", "240")
            report = json.loads((Path(directory) / "debug-compatibility.json").read_text())
            self.assertTrue(report["dismissed"])
            self.assertTrue((Path(directory) / "debug-compatibility-after.xml").exists())

    def test_android17_warning_ok_is_button2(self):
        # r1013 Pixel 10 hierarchy: button1 persists "Don't Show Again".
        xml = self.compatibility_xml().replace(
            b'android:id/button1', b'android:id/button2').replace(
            b'[100,200][300,280]', b'[1479,835][1647,977]').replace(
            b'</hierarchy>',
            b'<node package="android" resource-id="android:id/button1" '
            b'text="Don&apos;t Show Again" enabled="true" clickable="true" '
            b'bounds="[1647,835][2011,977]"/></hierarchy>')
        self.assertEqual(walkthrough.debug_compatibility_button(xml), (1563, 906))
        with self.assertRaisesRegex(RuntimeError, "unambiguous"):
            walkthrough.debug_compatibility_button(
                xml.replace(b'Don&apos;t Show Again', b'OK'))

    def test_debug_warning_selection_failure_saves_report(self):
        with TemporaryDirectory() as directory, \
                patch.object(walkthrough, "OUT", Path(directory)), \
                patch.object(walkthrough, "adb", side_effect=[
                    b"", self.compatibility_xml().replace(b'text="OK"', b'text="Other"')]):
            with self.assertRaisesRegex(RuntimeError, "unambiguous"):
                walkthrough.dismiss_debug_compatibility_warning()
            report = json.loads((Path(directory) / "debug-compatibility.json").read_text())
            self.assertFalse(report["dismissed"])
            self.assertIn("unambiguous", report["error"])

    def test_debug_warning_remaining_stops_route(self):
        with TemporaryDirectory() as directory, \
                patch.object(walkthrough, "OUT", Path(directory)), \
                patch.object(walkthrough, "capture"), \
                patch.object(walkthrough.time, "sleep"), \
                patch.object(walkthrough, "adb", side_effect=[
                    b"", self.compatibility_xml(), b"", b"", self.compatibility_xml()]):
            with self.assertRaisesRegex(RuntimeError, "remains"):
                walkthrough.dismiss_debug_compatibility_warning()
            report = json.loads((Path(directory) / "debug-compatibility.json").read_text())
            self.assertFalse(report["dismissed"])

    @staticmethod
    def look_sample(epoch, clock, yaw=0, alive=True):
        return (f'{epoch} 1 1 I godot: ANDROID_ROUTE route_json='
                + json.dumps({"alive": alive, "yaw": yaw})
                + f'\n\nANDROID_ROUTE_CLOCK={clock}\n')

    def test_post_look_wait_rejects_pre_turn_and_same_second_samples(self):
        initial = self.look_sample(100.1, 100)
        outputs = [self.look_sample(100.8, 101, .2),
                   self.look_sample(101.2, 101, .52)]
        with patch.object(walkthrough, "adb",
                          side_effect=[s.encode() for s in outputs]) as adb, \
                patch.object(walkthrough.time, "sleep") as sleep, \
                patch.object(walkthrough.time, "monotonic", return_value=200):
            output, state, evidence = walkthrough.post_look_observation(initial)
        self.assertEqual(output, outputs[-1])
        self.assertEqual(state["yaw"], .52)
        self.assertEqual(evidence["minimum_telemetry_epoch_s"], 101)
        self.assertEqual(evidence["polls"], 2)
        self.assertEqual(adb.call_count, 2)
        sleep.assert_called_once_with(.1)

    def test_post_look_wait_stops_on_dead_sample(self):
        initial = self.look_sample(100.1, 100)
        dead = self.look_sample(101.2, 101, alive=False)
        with patch.object(walkthrough, "adb", return_value=
                          dead.encode()), \
                patch.object(walkthrough.time, "sleep"), \
                patch.object(walkthrough.time, "monotonic", return_value=200):
            with self.assertRaisesRegex(RuntimeError, "Player died") as raised:
                walkthrough.post_look_observation(initial)
        self.assertEqual(raised.exception.raw_observation, dead)

    def test_precise_clock_accepts_fresh_sample_in_same_second(self):
        initial = self.look_sample(100.1, "100.200000000")
        outputs = [self.look_sample(100.2, "100.210000000"),
                   self.look_sample(100.5, "100.510000000", .52)]
        with patch.object(walkthrough, "adb",
                          side_effect=[s.encode() for s in outputs]), \
                patch.object(walkthrough.time, "sleep"), \
                patch.object(walkthrough.time, "monotonic", return_value=200):
            output, state, evidence = walkthrough.post_look_observation(initial)
        self.assertEqual(output, outputs[-1])
        self.assertEqual(state["yaw"], .52)
        self.assertAlmostEqual(evidence["minimum_telemetry_epoch_s"], 100.201)
        self.assertEqual(evidence["polls"], 2)

    def test_unsupported_nanosecond_clock_fails_closed(self):
        with self.assertRaisesRegex(RuntimeError, "malformed device clock"):
            walkthrough.route_state(self.look_sample(100.1, "100.%N"))

    def test_post_injection_sample_does_not_wait_for_another_log_period(self):
        initial = ("ANDROID_LOOK_END_CLOCK=100.200000000\n"
                   + self.look_sample(100.3, "100.400000000", .52))
        with patch.object(walkthrough, "adb") as adb:
            output, state, evidence = walkthrough.post_look_observation(initial)
        adb.assert_not_called()
        self.assertEqual(output, initial)
        self.assertEqual(state["yaw"], .52)
        self.assertAlmostEqual(evidence["minimum_telemetry_epoch_s"], 100.201)
        self.assertEqual(evidence["polls"], 0)

    def test_pre_injection_sample_still_waits(self):
        initial = ("ANDROID_LOOK_END_CLOCK=100.200000000\n"
                   + self.look_sample(100.2, "100.400000000"))
        fresh = self.look_sample(100.5, "100.600000000", .52)
        with patch.object(walkthrough, "adb", return_value=fresh.encode()), \
                patch.object(walkthrough.time, "sleep") as sleep:
            output, state, evidence = walkthrough.post_look_observation(initial)
        sleep.assert_not_called()
        self.assertEqual(output, fresh)
        self.assertEqual(evidence["polls"], 1)

    def test_invalid_injection_barriers_fail_closed(self):
        for clock in ("100.%N", "nan", "101.000000000", "80.000000000",
                      "100.100000000\nANDROID_LOOK_END_CLOCK=100.200000000"):
            with self.subTest(clock=clock), self.assertRaisesRegex(
                    RuntimeError, "post-look device clock"):
                walkthrough.post_look_observation(
                    f"ANDROID_LOOK_END_CLOCK={clock}\n"
                    + self.look_sample(100.3, "100.400000000"))

    def test_post_look_wait_times_out_when_telemetry_stalls(self):
        initial = self.look_sample(100.1, 100)
        with patch.object(walkthrough, "adb", return_value=initial.encode()), \
                patch.object(walkthrough.time, "sleep"), \
                patch.object(walkthrough.time, "monotonic",
                             side_effect=[200, 200.1, 203.1]):
            with self.assertRaisesRegex(RuntimeError, "No post-look") as raised:
                walkthrough.post_look_observation(initial)
        self.assertEqual(raised.exception.raw_observation, initial)

    def test_building_route_opt_in_arrival_and_camera_transform(self):
        state = dict(x=-31, z=49, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100, wall_normals_xz=[])
        route = walkthrough.RouteControls()
        route.building_route = False
        self.assertEqual(route.route_point(state), walkthrough.route_movement(state))
        route.building_route = True
        for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
            point = route.route_point(dict(state, yaw=yaw))
            lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
            self.assertAlmostEqual(math.cos(yaw)*lx + math.sin(yaw)*lz, -1)
            self.assertAlmostEqual(-math.sin(yaw)*lx + math.cos(yaw)*lz, 0)
            self.assertEqual(route.waypoint_index, 1)
        route.route_point(dict(state, x=-54))
        self.assertEqual(route.waypoint_index, 2)
        self.assertEqual(route.corner_arrivals, [1, 1, 0, 0, 0, 0, 0])

    def test_building_route_repeat_evidence_is_an_independent_snapshot(self):
        route = walkthrough.RouteControls()
        route.building_route = True
        state = dict(yaw=0, center_x=0, center_z=0, radius=110)
        route.route_point(dict(state, x=-31, z=49))
        first = route.waypoint_evidence
        for x, z in walkthrough.BUILDING_ROUTE_POINTS[1:] + walkthrough.BUILDING_ROUTE_POINTS[:1]:
            route.route_point(dict(state, x=x, z=z))
        self.assertEqual(route.corner_arrivals, [2, 1, 1, 1, 1, 1, 1])
        self.assertEqual(first["corner_arrivals"], [1, 0, 0, 0, 0, 0, 0])
        self.assertEqual(route.waypoint_evidence["arrived_corner"], 0)
        route.route_point(dict(state, x=-31, z=49))
        self.assertIsNone(route.waypoint_evidence["arrived_corner"])
        route.route_point(dict(state, x=0, z=0, radius=20))
        self.assertIn("fallback", route.waypoint_evidence)
        self.assertEqual(route.corner_arrivals, [2, 1, 1, 1, 1, 1, 1])

    def test_building_route_short_leg_scales_without_losing_direction(self):
        from android_multitouch import combat_events
        for distance in (2.01, 2.5, 4, 6.03686, 6.1, 8, 8.435, 12, 12.656, 16, 20, 22):
            for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
                route = walkthrough.RouteControls()
                route.building_route = True
                route.movement_supply_options = {}
                route.waypoint_index = 1
                point = route.route_point(dict(
                    x=-54 + distance, z=49, yaw=yaw,
                    center_x=0, center_z=0, radius=110))
                lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
                strength = math.hypot(lx, lz)
                self.assertGreater(strength * 100 / 105, .12)
                events = combat_events(
                    (1440, 900), point, 0, route_feedback=True,
                    route_distance_m=distance)
                release_ms = next(t for t, action, _ in events if action == 1)
                budget = release_ms / 100
                self.assertAlmostEqual(
                    route.waypoint_evidence["movement_budget_m"], budget)
                effective_strength = max(0, (strength * 100 / 105 - .12) / .88)
                self.assertLessEqual(effective_strength * budget, distance + .08)
                # Validate movement after the client's deadzone, not only the
                # injected touch radius. Integer pixel rounding is bounded.
                maximum_command = (100 / 105 - .12) / .88
                self.assertAlmostEqual(
                    effective_strength, min(distance / budget, maximum_command),
                    delta=.008)
                # r960: avoid double throttling during short combat pulses.
                if distance <= 8.435:
                    self.assertGreater(strength, distance / 14.74 * 1.4)
                self.assertLess(math.cos(yaw)*lx + math.sin(yaw)*lz, 0)
                self.assertAlmostEqual(-math.sin(yaw)*lx + math.cos(yaw)*lz, 0)
                self.assertEqual(route.waypoint_index, 1)

    def test_supply_route_budget_matches_actual_hold_and_bounds_corner_travel(self):
        from android_multitouch import combat_events
        for options in (dict(healing=True), dict(reloading=True),
                        dict(heal=True, healing=True), dict(reload=True),
                        dict(evading=True)):
            for distance in (2.17745, 2.29755, 4, 8, 12, 22):
                route = walkthrough.RouteControls()
                route.building_route = True
                route.waypoint_index = 1
                route.movement_supply_options = options
                point = route.route_point(dict(
                    x=-54 + distance, z=49, yaw=0,
                    center_x=0, center_z=0, radius=110))
                events = combat_events(
                    (1440, 900), point, 0, route_feedback=True,
                    route_distance_m=distance, **options)
                budget = next(t for t, action, _ in events if action == 1) / 100
                self.assertAlmostEqual(
                    route.waypoint_evidence["movement_budget_m"], budget)
                effective = max(0, (math.hypot(
                    point[0] - 180, point[1] - 650) / 105 - .12) / .88)
                self.assertLessEqual(effective * budget, distance + .08)
                self.assertLess(point[0], 180)
                self.assertEqual(point[1], 650)
                if options == dict(healing=True) and distance < 2.3:
                    self.assertGreater(effective, .85)

    def test_building_route_corner_turn_preserves_obstacle_clearance(self):
        corners = walkthrough.BUILDING_ROUTE_POINTS
        for index, (cx, cz) in enumerate(corners):
            for direction in (-1, 1):
                for angle in range(0, 360, 15):
                    route = walkthrough.RouteControls()
                    route.building_route = True
                    route.waypoint_index = index
                    route.waypoint_direction = direction
                    x = cx + .99 * math.cos(math.radians(angle))
                    z = cz + .99 * math.sin(math.radians(angle))
                    route.route_point(dict(x=x, z=z, yaw=0, center_x=0,
                                           center_z=0, radius=200))
                    px, pz = route.waypoint_evidence["target_xz"]
                    self.assertEqual(route.waypoint_index, (index + direction) % len(corners))
                    self.assertTrue(
                        walkthrough.on_route_segment(x, z, (cx, cz), (px, pz)))
        route = walkthrough.RouteControls()
        route.building_route = True
        # Entering laterally from behind the canopy must use fallback.
        state = dict(x=-42, z=44, yaw=0, center_x=0, center_z=0, radius=200)
        self.assertEqual(route.route_point(state), walkthrough.route_movement(state))
        self.assertIn("fallback", route.waypoint_evidence)

    def test_legacy_rear_shortcut_is_outside_verified_corridor(self):
        route = walkthrough.RouteControls()
        route.building_route = True
        route.waypoint_index = 3
        for x, z in ((-32.412357, 24.106857), (-30.869, 25.999)):
            state = dict(x=x, z=z, yaw=2.339273,
                         center_x=-2.2176, center_z=4.9689, radius=98.8167)
            self.assertEqual(route.route_point(state), walkthrough.route_movement(state))
            self.assertIsNone(route.waypoint_index)
            self.assertIn("fallback", route.waypoint_evidence)

    def test_building_route_reverses_at_unsafe_corner(self):
        route = walkthrough.RouteControls()
        route.building_route = True
        state = dict(x=-31, z=49, yaw=0, center_x=0, center_z=0,
                     radius=90, telemetry_epoch_s=100)
        for x, z, target in ((-31, 49, 6), (-28, 38, 5),
                             (-21, 30, 4), (-21, 26, 3),
                             (-28, 19, 2), (-54, 24, 3)):
            route.route_point(dict(state, x=x, z=z))
            self.assertEqual(route.waypoint_index, target)

    def test_building_route_retargets_shrinking_zone_without_diagonal(self):
        route = walkthrough.RouteControls()
        route.building_route = True
        state = dict(x=-40, z=49, yaw=0, center_x=0, center_z=0,
                     radius=110)
        route.waypoint_index = 1
        route.route_point(dict(state, radius=90))
        self.assertEqual(route.waypoint_index, 0)

    def test_building_route_yields_without_safe_reachable_segment(self):
        route = walkthrough.RouteControls()
        route.building_route = True
        state = dict(x=-31, z=49, yaw=0, center_x=0, center_z=0,
                     radius=75, telemetry_epoch_s=100)
        point, evidence = route.choose(state)
        self.assertEqual(point, walkthrough.route_movement(state))
        self.assertIsNone(route.waypoint_index)
        self.assertIn("fallback", evidence["building_route"])
        # Inside the building footprint no corner is directly reachable.
        state.update(x=-42, z=34, radius=110)
        self.assertEqual(route.route_point(state), walkthrough.route_movement(state))
        self.assertIsNone(route.waypoint_index)

    def test_live_views_preserve_partial_evidence_on_death(self):
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "combat_cycle",
                             side_effect=[None, RuntimeError("Player died")]), \
                patch.object(walkthrough.subprocess, "run", return_value=
                             subprocess.CompletedProcess(
                                 "adb", 0, stdout=b"\x89PNG\r\n\x1a\nsynthetic")) as run, \
                patch.object(walkthrough, "probe") as probe:
            with self.assertRaisesRegex(RuntimeError, "Player died"):
                walkthrough.diagnose_combat_views((1440, 900), None, None)
            report = json.loads((Path(tmp) / "live-combat-diagnostic.json").read_text())
            self.assertFalse(report["acceptance"])
            self.assertEqual(report["gameplay_error"], "Player died")
            self.assertEqual(len(report["views"]), 1)
            self.assertTrue((Path(tmp) / report["views"][0]["path"]).exists())
            self.assertEqual(run.call_args.kwargs["timeout"], 10)
            probe.assert_not_called()

    def test_live_diagnostic_returns_before_performance_sampling(self):
        with patch.dict(os.environ, {"ANDROID_COMBAT_VIEW_DIAGNOSTIC": "1",
                                     "ANDROID_INITIAL_ROUTE_PROBE": "0"}), \
                patch.object(walkthrough, "adb",
                             return_value=b"ANDROID_STARTUP: interface ready"), \
                patch.object(walkthrough.time, "sleep"), \
                patch.object(walkthrough, "capture", return_value=(1440, 900)), \
                patch.object(walkthrough, "initial_route"), \
                patch.object(walkthrough, "phase", return_value=nullcontext()), \
                patch.object(walkthrough, "diagnose_combat_views") as diagnostic, \
                patch.object(walkthrough, "measure_combat") as measurement:
            walkthrough.main()
            diagnostic.assert_called_once()
            measurement.assert_not_called()

    def test_combat_screenshot_follows_completed_measurement_and_saved_logs(self):
        telemetry = ("ANDROID_PERF fps=60 p95_ms=17\n"
                     "ANDROID_GAMEPLAY phase=live alive=true\n") * 5
        events = []
        with TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "warmup.logcat").write_text("warmup")

            def measure(*args):
                events.append("measurement-complete")
                return {"log_marker": "start", "log_end_marker": "end"}

            def capture(name):
                if name == "05-combat-after-measurement":
                    self.assertEqual(events, ["measurement-complete"])
                    report = json.loads(
                        (directory / "gameplay-performance.json").read_text())
                    self.assertEqual(len(report["samples"]), 4)
                    self.assertTrue((directory / "native-walkthrough.logcat").exists())
                    events.append("combat-screenshot")
                return (1440, 900)

            with patch.dict(os.environ, {"ANDROID_COMBAT_VIEW_DIAGNOSTIC": "0",
                                         "ANDROID_INITIAL_ROUTE_PROBE": "0",
                                         "ANDROID_GROUND_MATERIAL_DIAGNOSTIC": "0",
                                         "ANDROID_DISMISS_DEBUG_COMPAT_WARNING": "0"}), \
                    patch.object(walkthrough, "OUT", directory), \
                    patch.object(walkthrough, "PROFILE_GAME", False), \
                    patch.object(walkthrough, "adb",
                                 return_value=b"ANDROID_STARTUP: interface ready"), \
                    patch.object(walkthrough.time, "sleep"), \
                    patch.object(walkthrough, "capture", side_effect=capture), \
                    patch.object(walkthrough, "initial_route"), \
                    patch.object(walkthrough, "measure_combat", side_effect=measure), \
                    patch.object(walkthrough, "measurement_logs", return_value=telemetry):
                walkthrough.main()
            self.assertEqual(events, ["measurement-complete", "combat-screenshot"])
            phases = [json.loads(line) for line in
                      (directory / "phase-commands.jsonl").read_text().splitlines()]
            self.assertEqual([p["name"] for p in phases],
                             ["active-warmup-and-presentation", "post-measurement-visual"])
            self.assertLessEqual(phases[0]["host_end_monotonic_s"],
                                 phases[1]["host_start_monotonic_s"])

    def test_failure_capture_is_bounded_and_retains_partial_evidence(self):
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough.subprocess, "run", side_effect=[
                    subprocess.TimeoutExpired("adb", 10),
                    subprocess.CompletedProcess("adb", 0, stdout=b"damage log"),
                ]) as run:
            evidence = {"gameplay_error": "Player died"}
            walkthrough.capture_combat_failure(evidence, "combat-failure")
            self.assertEqual(evidence["gameplay_error"], "Player died")
            self.assertIn("failure_png_error", evidence)
            self.assertEqual((Path(tmp) / evidence["failure_logcat_path"]).read_bytes(),
                             b"damage log")
            self.assertEqual(run.call_count, 2)
            for call in run.call_args_list:
                self.assertEqual(call.kwargs["timeout"], 10)
                self.assertTrue(call.kwargs["check"])

    def test_combat_seed_waits_for_ready(self):
        ready = MagicMock()
        ready.wait.side_effect = [False, False, True]
        pending = MagicMock()
        pending.done.return_value = False
        walkthrough.wait_for_combat_seed(pending, ready)
        self.assertEqual(ready.wait.call_count, 3)
        pending.result.assert_not_called()

    def test_combat_seed_keeps_gameplay_active_until_ready(self):
        ready = MagicMock()
        ready.wait.side_effect = [False, False, True]
        pending = MagicMock()
        pending.done.return_value = False
        gameplay = MagicMock()
        walkthrough.wait_for_combat_seed(pending, ready, on_wait=gameplay)
        self.assertEqual(gameplay.call_count, 2)
        pending.result.assert_not_called()

    def test_combat_seed_gameplay_failure_is_not_ignored(self):
        ready = MagicMock()
        ready.wait.return_value = False
        pending = MagicMock()
        pending.done.return_value = False
        with self.assertRaisesRegex(RuntimeError, "Player died"):
            walkthrough.wait_for_combat_seed(
                pending, ready,
                on_wait=MagicMock(side_effect=RuntimeError("Player died")))

    def test_combat_seed_failure_and_timeout_preserve_evidence_without_input(self):
        for failure in ("collector", "timeout"):
            with self.subTest(failure=failure):
                executor = MagicMock()
                pending = executor.__enter__.return_value.submit.return_value
                pending.done.return_value = failure == "collector"
                pending.result.return_value = {"valid": False, "error": "no layer"}
                real_wait = walkthrough.wait_for_combat_seed
                with TemporaryDirectory() as tmp, \
                        patch.object(walkthrough, "OUT", Path(tmp)), \
                        patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                        patch.object(walkthrough, "wait_for_combat_seed",
                                     side_effect=lambda p, r, **kw: real_wait(
                                         p, r, timeout=0, **kw)), \
                        patch.object(walkthrough, "combat_cycle") as combat, \
                        patch.object(walkthrough, "capture_combat_failure"), \
                        patch.object(walkthrough, "adb", return_value=b""):
                    with self.assertRaises((RuntimeError, TimeoutError)):
                        walkthrough.measure_combat((1440, 900), 25, 0)
                    combat.assert_not_called()
                    self.assertTrue(executor.__enter__.return_value.submit.call_args
                                    .kwargs["stop"].is_set())
                    evidence = json.loads((Path(tmp) /
                        "aborted-combat-diagnostic.json").read_text())
                    self.assertEqual(evidence["completed_cycles"], 0)
                    self.assertFalse(evidence["acceptance"])

    def test_combat_death_stops_collector_and_preserves_failure(self):
        for collector_fails in (False, True):
            with self.subTest(collector_fails=collector_fails):
                def synthetic_probe(package, output, seconds, ready, stop):
                    output.mkdir(parents=True)
                    (output / "raw-evidence.txt").write_text("synthetic poll")
                    (output / "intervals").mkdir()
                    (output / "intervals" / "timestamps.json").write_text(
                        json.dumps([1000000, 17000000, 42000000]))
                    ready.set()
                    if not stop.wait(2):
                        raise AssertionError("Combat collector was not stopped")
                    if collector_fails:
                        raise OSError("collector failure")
                    return {"valid": False}

                with TemporaryDirectory() as tmp, \
                        patch.object(walkthrough, "OUT", Path(tmp)), \
                        patch.object(walkthrough, "probe", side_effect=synthetic_probe), \
                        patch.object(walkthrough, "combat_cycle",
                                     side_effect=RuntimeError("Player died")), \
                        patch.object(walkthrough, "capture_combat_failure") as capture, \
                        patch.object(walkthrough, "adb", return_value=b""):
                    with self.assertRaisesRegex(RuntimeError, "Player died"):
                        walkthrough.measure_combat((1440, 900), 300, 0)
                    evidence = json.loads((Path(tmp) /
                        "aborted-combat-diagnostic.json").read_text())
                    self.assertFalse(evidence["acceptance"])
                    self.assertEqual(evidence["completed_cycles"], 0)
                    self.assertEqual(evidence["gameplay_error"], "Player died")
                    self.assertTrue((Path(tmp) / "present-probe" /
                                     "raw-evidence.txt").exists())
                    self.assertEqual(json.loads((Path(tmp) / "present-probe" /
                        "diagnostic-frame-times.json").read_text()),
                        {"frame_times_ms": [16, 25]})
                    capture.assert_called_once()
                    self.assertIn("present_probe" if not collector_fails else "collector_error",
                                  capture.call_args.args[0])
                    if collector_fails:
                        self.assertEqual(evidence["collector_error"], "collector failure")
                    else:
                        self.assertFalse(evidence["present_probe"]["valid"])

    def test_r764_clear_escape_stops_before_opposite_wall(self):
        route = walkthrough.RouteControls()
        blocked = dict(x=-22.6493, z=45.8667, yaw=-.2128, center_x=0,
                       center_z=0, radius=110, telemetry_epoch_s=100,
                       planar_speed=0, heal_left=0,
                       wall_normals_xz=[[-.2182, .9759], [0, 1]])
        route.choose(blocked)
        clear = dict(blocked, x=-23.211, z=66.425, yaw=-.1925,
                     telemetry_epoch_s=104.05, planar_speed=8,
                     wall_normals_xz=[])
        point, evidence = route.choose(clear)
        self.assertEqual(evidence["reason"], "clear progress; end recovery")
        self.assertGreater(evidence["recovery_displacement_m"], 20)
        self.assertTrue(evidence["bounded_clearance"])
        # Stop travelling outward without reversing straight into the wall.
        wx, wz = route.clearance[1:3]
        self.assertAlmostEqual(wx * -.1098 + wz * .9939, 0, delta=.01)
        self.assertIsNone(route.recovery)
        self.assertEqual(route.choose(clear)[0], point)

    def test_r788_corner_clearance_is_bounded_and_yields_to_contact(self):
        blocked = dict(x=-33.3690605, z=38.6801071, yaw=-.0966725,
                       center_x=-2.1129594, center_z=-4.8559647,
                       radius=102.0333333, telemetry_epoch_s=1790753289.426,
                       planar_speed=0, heal_left=0,
                       wall_normals_xz=[[0, 1], [1, 0]])
        clear = dict(blocked, x=-29.2512226, z=43.5980911,
                     yaw=-.1480059, telemetry_epoch_s=1790753291.441,
                     planar_speed=8.51056, wall_normals_xz=[])
        route = walkthrough.RouteControls()
        route.choose(blocked)
        point, evidence = route.choose(clear)
        self.assertTrue(evidence["bounded_clearance"])
        sx, sz = route.clearance[1:3]
        self.assertAlmostEqual(sx + sz, 0)
        self.assertNotEqual(point, walkthrough.route_movement(clear))
        turned = dict(clear, yaw=.7)
        turned_point, _ = route.choose(turned)
        lx, lz = (turned_point[0] - 180) / 100, (turned_point[1] - 650) / 100
        self.assertAlmostEqual(math.cos(.7) * lx + math.sin(.7) * lz, sx, delta=.01)
        self.assertAlmostEqual(-math.sin(.7) * lx + math.cos(.7) * lz, sz, delta=.01)
        healing = dict(clear, telemetry_epoch_s=clear["telemetry_epoch_s"] + 2,
                       heal_left=2.633, planar_speed=0)
        healing_point, _ = route.choose(healing)
        self.assertEqual(healing_point, point)
        self.assertIsNotNone(route.clearance)
        for changes in (dict(telemetry_epoch_s=clear["telemetry_epoch_s"] + 3, heal_left=1),
                        dict(x=clear["x"] + 9), dict(radius=50)):
            with self.subTest(changes=changes):
                route.clearance = (clear["telemetry_epoch_s"], sx, sz, clear["x"], clear["z"])
                route.previous = (clear["telemetry_epoch_s"], clear["x"], clear["z"])
                route.choose(dict(clear, **changes))
                self.assertIsNone(route.clearance)
        route.clearance = (clear["telemetry_epoch_s"], sx, sz, clear["x"], clear["z"])
        _, evidence = route.choose(dict(clear, telemetry_epoch_s=clear["telemetry_epoch_s"] + 1,
                                        planar_speed=0, wall_normals_xz=[[-sx, -sz]]))
        self.assertIn("fresh blocked wall contact", evidence["reason"])
        self.assertIsNone(route.clearance)

    def test_r801_escape_ends_when_stick_release_samples_zero_speed(self):
        route = walkthrough.RouteControls()
        blocked = dict(x=-34.2695236206055, z=41.7419242858887,
                       yaw=-.12461832306385, center_x=0, center_z=0,
                       radius=110, telemetry_epoch_s=1790754488.109,
                       planar_speed=0, heal_left=0,
                       wall_normals_xz=[[.606623709201813, .794989109039307]])
        route.choose(blocked)
        clear = dict(blocked, x=-30.0837821960449, z=48.0299224853516,
                     yaw=-.11895718972683, telemetry_epoch_s=1790754491.118,
                     wall_normals_xz=[])
        _, evidence = route.choose(clear)
        self.assertEqual(evidence["reason"], "clear progress; end recovery")
        self.assertAlmostEqual(evidence["recovery_displacement_m"], 7.55, delta=.02)
        self.assertIsNone(route.recovery)
        self.assertTrue(evidence["bounded_clearance"])

    def test_escape_distance_requires_fresh_clear_observation(self):
        state = dict(x=10, z=40, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=105, planar_speed=8,
                     heal_left=0, wall_normals_xz=[])
        for changes in (dict(telemetry_epoch_s=100),
                        dict(wall_normals_xz=[[1, 0]]),
                        dict(x=3)):
            with self.subTest(changes=changes):
                route = walkthrough.RouteControls()
                route.previous = (100, 0, 40)
                route.recovery = (100, 1, 0, 0, 40)
                _, evidence = route.choose(dict(state, **changes))
                self.assertEqual(evidence["reason"], "bounded lateral recovery")
                self.assertIsNotNone(route.recovery)

    def test_new_corner_overrides_escape_even_when_orbit_points_outward(self):
        # r758: a previous northeast escape reached a southwest-facing corner.
        state = dict(x=-8.7702, z=64.3771, yaw=-.1365, center_x=0,
                     center_z=0, radius=110, telemetry_epoch_s=108.102,
                     planar_speed=0, heal_left=0,
                     wall_normals_xz=[[-.99796, 0], [0, -1]])
        route = walkthrough.RouteControls()
        route.previous = (104.06, -19.443, 53.537)
        route.recovery = (100, .8146, .58, -33.915, 41.581)
        route.contact_recovery_epoch = 100
        point, evidence = route.choose(state)
        self.assertIn("fresh blocked wall contact", evidence["reason"])
        self.assertLess(route.recovery[1], 0)
        self.assertLess(route.recovery[2], 0)
        self.assertEqual(route.choose(state)[0], point)

    def test_multitouch_heal_uses_no_separate_adb_tap(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True, health=72, medkits=2,
                     heal_left=0, reload_left=0, ammo=20, reserve=90,
                     telemetry_epoch_s=100)
        touch = MagicMock()
        touch.combat_events.return_value = [(1194, 1, [])]
        supplies = walkthrough.SupplyControls()
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.dict(os.environ, {"ANDROID_MULTITOUCH": "1"}), \
                patch.dict(sys.modules, {"android_multitouch": touch}), \
                patch.object(walkthrough, "route_state", return_value=state), \
                patch.object(walkthrough.time, "monotonic", return_value=200) as now, \
                patch.object(walkthrough, "tap") as tap, \
                patch.object(walkthrough, "adb") as adb:
            walkthrough.combat_cycle((1440, 900), 0, supplies)
            tap.assert_not_called()
            adb.assert_not_called()
            self.assertTrue(touch.run_combat.call_args.kwargs["heal"])
            self.assertTrue(touch.run_combat.call_args.args[4])
            self.assertFalse(touch.run_combat.call_args.args[5])
            now.return_value = 201.2
            state["telemetry_epoch_s"] = 101
            walkthrough.combat_cycle((1440, 900), 1, supplies)
            self.assertFalse(touch.run_combat.call_args.kwargs["heal"])
            self.assertTrue(touch.run_combat.call_args.args[4])
            self.assertFalse(touch.run_combat.call_args.args[5])
            now.return_value = 203.5
            state["health"] = 100
            state["ammo"] = 5
            walkthrough.combat_cycle((1440, 900), 2, supplies)
            self.assertFalse(touch.run_combat.call_args.args[4])
            self.assertTrue(touch.run_combat.call_args.args[5])

    def test_grenade_warning_defers_combat_only_until_warning_clears(self):
        state = dict(x=-45, z=49, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True, health=100, medkits=2,
                     heal_left=0, reload_left=0, ammo=20, reserve=90,
                     telemetry_epoch_s=100, frag_warning=True)
        touch = MagicMock()
        touch.combat_events.return_value = [(932, 1, [])]
        controls = walkthrough.RouteControls()
        controls.building_route = True
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.dict(os.environ, {"ANDROID_MULTITOUCH": "1"}), \
                patch.dict(sys.modules, {"android_multitouch": touch}), \
                patch.object(walkthrough, "RouteControls", return_value=controls), \
                patch.object(walkthrough, "route_state", return_value=state):
            walkthrough.combat_cycle((1440, 900), 0)
            self.assertTrue(controls.movement_supply_options["evading"])
            self.assertTrue(touch.run_combat.call_args.kwargs["evading"])
            self.assertTrue(touch.combat_events.call_args.kwargs["evading"])
            state["frag_warning"] = False
            walkthrough.combat_cycle((1440, 900), 1)
            self.assertNotIn("evading", controls.movement_supply_options)
            self.assertNotIn("evading", touch.run_combat.call_args.kwargs)
            decisions = [json.loads(line) for line in
                         (Path(tmp) / "route-decisions.jsonl").read_text().splitlines()]
            self.assertEqual([row["combat_deferred_for_grenade"] for row in decisions],
                             [True, False])

    def test_adjacent_combat_cycles_reuse_post_touch_observation(self):
        state = dict(x=0, z=40, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True, health=100, medkits=2,
                     heal_left=0, reload_left=0, ammo=20, reserve=90)
        output = ('100 1 1 I godot: ANDROID_ROUTE route_json='
                  + json.dumps(state) + '\n\nANDROID_ROUTE_CLOCK=101\n')
        touch = MagicMock()
        touch.combat_events.return_value = [(3056, 1, [])]
        touch.run_combat.return_value = output
        route = walkthrough.RouteControls()
        supplies = walkthrough.SupplyControls()
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.dict(os.environ, {"ANDROID_MULTITOUCH": "1"}), \
                patch.dict(sys.modules, {"android_multitouch": touch}), \
                patch.object(walkthrough.time, "monotonic", return_value=200), \
                patch.object(walkthrough, "adb", return_value=output.encode()) as adb:
            for cycle in range(2):
                walkthrough.combat_cycle((1440, 900), cycle, supplies, route)
            adb.assert_called_once()
            self.assertEqual(touch.run_combat.call_count, 2)
            self.assertEqual(touch.run_combat.call_args.kwargs,
                             {"observation_command": walkthrough.ROUTE_OBSERVATION_COMMAND,
                              "heal": False})
            observations = [
                json.loads(line) for line in
                (Path(tmp) / "combat-observations.jsonl").read_text().splitlines()
            ]
            self.assertEqual([row["cycle"] for row in observations], [0, 1])
            self.assertEqual(observations[0]["supply_action"], "none")
            self.assertEqual(observations[0]["before"]["health"], 100)
            self.assertEqual(observations[0]["after"]["health"], 100)
            self.assertEqual(observations[0]["host_received_monotonic_s"], 200)
            # Death in the final post-touch sample aborts that cycle itself.
            touch.run_combat.return_value = output.replace('"alive": true', '"alive": false')
            with self.assertRaisesRegex(RuntimeError, "Player died"):
                walkthrough.combat_cycle((1440, 900), 2, supplies, route)
            self.assertIsNone(route.pending_observation)
            failed = json.loads(
                (Path(tmp) / "combat-observations.jsonl").read_text().splitlines()[-1])
            self.assertEqual(failed["cycle"], 2)
            self.assertIsNone(failed["after"])
            self.assertIn("Player died", failed["observation_error"])
            self.assertIn('"alive": false', failed["raw_observation"])
            self.assertEqual(failed["before"]["health"], 100)

    def test_adjacent_observation_is_single_use_and_host_age_is_added(self):
        output = ('100 1 1 I godot: ANDROID_ROUTE route_json={"alive":true}\n'
                  '\nANDROID_ROUTE_CLOCK=111\n')
        route = walkthrough.RouteControls()
        route.pending_observation = (output, 200)
        with patch.object(walkthrough.time, "monotonic", return_value=200.125), \
                patch.object(walkthrough, "adb", return_value=output.encode()) as adb:
            state = route.observe()
            self.assertEqual(state["telemetry_age_s"], 11.125)
            adb.assert_not_called()
            self.assertIsNone(route.pending_observation)
            route.observe()
            adb.assert_called_once()

    def test_delayed_observation_refreshes_and_invalid_cached_state_fails(self):
        live = ('100 1 1 I godot: ANDROID_ROUTE route_json={"alive":true}\n'
                '\nANDROID_ROUTE_CLOCK=100\n')
        for elapsed in (.251, 10, -1):
            route = walkthrough.RouteControls()
            route.pending_observation = ("invalid", 200)
            with patch.object(walkthrough.time, "monotonic", return_value=200 + elapsed), \
                    patch.object(walkthrough, "adb", return_value=live.encode()) as adb:
                self.assertTrue(route.observe()["alive"])
                adb.assert_called_once()
        for bad in (live.replace("true", "false"),
                    live.replace('{"alive":true}', '{"alive":'),
                    live.replace("CLOCK=100", "CLOCK=112")):
            route.pending_observation = (bad, 200)
            with patch.object(walkthrough.time, "monotonic", return_value=200.125), \
                    patch.object(walkthrough, "adb") as adb:
                with self.assertRaises(RuntimeError):
                    route.observe()
                adb.assert_not_called()
                self.assertIsNone(route.pending_observation)

    def test_device_route_filter_preserves_latest_invalid_record(self):
        # Execute the real shell expression; mocks of adb alone cannot catch
        # quoting, filtering, or pipeline exit-status mistakes.
        for newest in ('{"alive":false}', '{"alive":'):
            log = ('100 1 1 I godot: ANDROID_ROUTE route_json={"alive":true}\n'
                   + "unrelated log noise\n" * 2000
                   + '101 1 1 I godot: ANDROID_GAMEPLAY route_json=' + newest + '\n'
                   + '102 1 1 I godot: ANDROID_GAMEPLAY movement_json={}\n')
            with TemporaryDirectory() as folder:
                Path(folder, "input.log").write_text(log)
                command = ("logcat() { cat input.log; }; date() { echo 102; }; "
                           + walkthrough.ROUTE_OBSERVATION_COMMAND)
                output = subprocess.check_output(["bash", "-c", command], cwd=folder)
            self.assertEqual(output.decode(),
                             '101 1 1 I godot: ANDROID_GAMEPLAY route_json='
                             + newest + '\n\nANDROID_ROUTE_CLOCK=102\n')
            with patch.object(walkthrough, "adb", return_value=output):
                with self.assertRaises(RuntimeError):
                    walkthrough.route_state()

    def test_device_route_filter_propagates_logcat_failure(self):
        command = ("logcat() { echo '100 1 1 I godot: ANDROID_ROUTE route_json={}'; return 7; }; "
                   + walkthrough.ROUTE_OBSERVATION_COMMAND)
        result = subprocess.run(["bash", "-c", command], capture_output=True)
        self.assertEqual(result.returncode, 7)
        self.assertNotIn(b"ANDROID_ROUTE_CLOCK", result.stdout)

    def test_device_route_filter_streams_dump_larger_than_argument_limit(self):
        # Model Android's external printf, which the host shell builtin masked.
        log = ("unrelated " + "x" * 1000 + "\n") * 1999
        record = '101 1 1 I godot: ANDROID_ROUTE route_json={"alive":true}'
        with TemporaryDirectory() as folder:
            Path(folder, "input.log").write_text(log + record + "\n")
            command = ("printf() { /usr/bin/printf \"$@\"; }; "
                       "logcat() { cat input.log; }; date() { echo 102; }; "
                       + walkthrough.ROUTE_OBSERVATION_COMMAND)
            result = subprocess.run(["bash", "-c", command], cwd=folder,
                                    capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, b"")
        self.assertEqual(result.stdout.decode(),
                         record + "\n\nANDROID_ROUTE_CLOCK=102\n")

    def test_empty_device_route_filter_does_not_claim_success(self):
        command = "logcat() { echo unrelated; }; " + walkthrough.ROUTE_OBSERVATION_COMMAND
        result = subprocess.run(["bash", "-c", command], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(b"ANDROID_ROUTE_CLOCK", result.stdout)

    def test_device_route_filter_ignores_adbd_command_echo(self):
        # Pixel logcat includes adbd's shell command, including our grep pattern.
        # It is newer than the real telemetry and used to be parsed as JSON.
        record = '101 29007 29043 I godot   : ANDROID_ROUTE route_json={"alive":true}'
        echo = ("102 1296 1296 I adbd    : adbd service requested "
                "'shell,v2,TERM=unknown,raw:"
                + walkthrough.ROUTE_OBSERVATION_COMMAND + "'")
        with TemporaryDirectory() as folder:
            Path(folder, "input.log").write_text(record + "\n" + echo + "\n")
            command = ("logcat() { cat input.log; }; date() { echo 102; }; "
                       + walkthrough.ROUTE_OBSERVATION_COMMAND)
            output = subprocess.check_output(["bash", "-c", command], cwd=folder)
        state = walkthrough.route_state(output.decode())
        self.assertTrue(state["alive"])
        self.assertEqual(state["telemetry_epoch_s"], 101)

    def test_r650_corner_contact_escapes_both_walls_without_waiting(self):
        import math
        for yaw in (-.137209957790375, 0, math.pi / 2):
            state = dict(x=-33.3690567, z=30.6803303, yaw=yaw,
                         center_x=0, center_z=0, radius=110,
                         telemetry_epoch_s=105, planar_speed=0,
                         wall_normals_xz=[[1, 0], [0, 1], [1, 0]])
            route = walkthrough.RouteControls()
            route.choose(dict(state, x=-28.32275, z=41.33123,
                              telemetry_epoch_s=100, wall_normals_xz=[]))
            point, evidence = route.choose(state)
            self.assertIn("blocked wall contact", evidence["reason"])
            lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
            wx = math.cos(yaw) * lx + math.sin(yaw) * lz
            wz = -math.sin(yaw) * lx + math.cos(yaw) * lz
            self.assertGreater(wx, .69)
            self.assertGreater(wz, .69)
            self.assertEqual(route.choose(state)[0], point)
            self.assertEqual(route.recovery[0], 105)

    def test_r843_healing_wall_contact_retains_outward_input(self):
        # Recorded cycles 29/30: treatment was still active while the orbit
        # pressed into the wall for two consecutive short movement cycles.
        state = dict(x=-29.662914276123, z=27.0009384155273,
                     yaw=-2.09942201555034, center_x=-2.92412543296814,
                     center_z=23.5450401306152, radius=80,
                     telemetry_epoch_s=1790759095.646, planar_speed=0,
                     heal_left=2.78333333333334, wall_normals_xz=[[0, 1]])
        route = walkthrough.RouteControls()
        point, evidence = route.choose(state)
        self.assertIn("blocked wall contact", evidence["reason"])
        for sample in (state, dict(state, x=-29.5963878631592,
                                   yaw=-2.61836275747081, heal_left=.7667,
                                   telemetry_epoch_s=1790759097.665)):
            point, _ = route.choose(sample)
            lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
            wz = -math.sin(sample["yaw"]) * lx + math.cos(sample["yaw"]) * lz
            self.assertGreater(wz, .98)
        self.assertIsNotNone(route.recovery)

    def test_contact_recovery_excludes_motion_and_opposed_walls(self):
        state = dict(x=-33.369, z=30.680, yaw=0, center_x=0,
                     center_z=0, radius=110, telemetry_epoch_s=105,
                     planar_speed=0, wall_normals_xz=[[1, 0], [0, 1]])
        for changes in (dict(planar_speed=3),
                        dict(wall_normals_xz=[[1, 0], [-1, 0]]),
                        dict(wall_normals_xz=[[float("nan"), 0]])):
            fresh = dict(state, **changes)
            route = walkthrough.RouteControls()
            self.assertEqual(route.choose(fresh)[0], walkthrough.route_movement(fresh))
            self.assertIsNone(route.recovery)

    def test_r678_edge_wall_escape_then_resume_inward_on_fresh_progress(self):
        import math
        state = dict(x=-39.5413513183594, z=28.1392574310303,
                     yaw=-.146364094877243, center_x=17.1514415740967,
                     center_z=-6.14176845550537, radius=82.3500000000023,
                     telemetry_epoch_s=1790735333.957, planar_speed=0,
                     wall_normals_xz=[[-.832238972187042, -.554417073726654]])
        for changes in (dict(planar_speed=3), dict(wall_normals_xz=[])):
            route = walkthrough.RouteControls()
            point, evidence = route.choose(state)
            self.assertIn("blocked wall contact", evidence["reason"])
            self.assertNotEqual(point, walkthrough.route_movement(state))
            # Duplicate observations retain a world-space escape through turns.
            turned = dict(state, yaw=state["yaw"] + math.pi / 2)
            point, evidence = route.choose(turned)
            lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
            wx = math.cos(turned["yaw"]) * lx + math.sin(turned["yaw"]) * lz
            wz = -math.sin(turned["yaw"]) * lx + math.cos(turned["yaw"]) * lz
            self.assertGreater(wx * state["wall_normals_xz"][0][0]
                               + wz * state["wall_normals_xz"][0][1], .98)
            fresh = dict(turned, telemetry_epoch_s=state["telemetry_epoch_s"] + 5,
                         **changes)
            point, evidence = route.choose(fresh)
            self.assertEqual(point, walkthrough.route_movement(fresh))
            self.assertEqual(evidence["reason"], "zone margin; prefer inward route")
            self.assertIsNone(route.recovery)

    def test_separate_route_survives_truncated_collision_log(self):
        state = dict(alive=True, x=2, z=80, yaw=0, center_x=0,
                     center_z=0, radius=110)
        log = ("100.5 1 1 I godot: ANDROID_GAMEPLAY movement_json=" +
               '{"contacts":[' + "x" * 1000 + "\n" +
               "100.5 1 1 I godot: ANDROID_ROUTE route_json=" + json.dumps(state))
        with patch.object(walkthrough, "adb",
                          return_value=log.encode() + b"\nANDROID_ROUTE_CLOCK=101\n"):
            self.assertEqual(walkthrough.route_state()["x"], 2)

    def test_malformed_newest_route_never_reuses_old_live_state(self):
        log = ('100 1 1 I godot: ANDROID_ROUTE route_json={"alive":true}\n'
               '101 1 1 I godot: ANDROID_ROUTE route_json={"alive":')
        with patch.object(walkthrough, "adb",
                          return_value=log.encode() + b"\nANDROID_ROUTE_CLOCK=101\n"):
            with self.assertRaisesRegex(RuntimeError, "Malformed route telemetry"):
                walkthrough.route_state()

    def test_warmup_death_preserves_diagnostic_and_propagates(self):
        def synthetic_probe(package, output, seconds, ready, stop):
            (output / "intervals").mkdir(parents=True)
            (output / "intervals" / "timestamps.json").write_text(
                json.dumps([1000000, 17000000, 42000000]))
            if not stop.wait(2):
                raise AssertionError("Warmup collector was not stopped")
            return {"valid": False, "error": "Diagnostic stopped"}

        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "probe", side_effect=synthetic_probe), \
                patch.object(walkthrough, "combat_cycle",
                             side_effect=RuntimeError("Player died")), \
                patch.object(walkthrough, "system_trace") as trace, \
                patch.object(walkthrough, "capture_combat_failure") as capture, \
                patch.object(walkthrough, "adb") as adb:
            with self.assertRaisesRegex(RuntimeError, "Player died"):
                walkthrough.measure_combat((1440, 900), 300, 60)
            evidence = json.loads(
                (Path(tmp) / "warmup-presentation-diagnostic.json").read_text())
            self.assertFalse(evidence["acceptance"])
            self.assertEqual(evidence["gameplay_error"], "Player died")
            self.assertFalse(evidence["present_probe"]["valid"])
            self.assertEqual(json.loads((Path(tmp) / "warmup-present-probe" /
                "diagnostic-frame-times.json").read_text())["frame_times_ms"], [16, 25])
            self.assertFalse((Path(tmp) / "present-probe").exists())
            adb.assert_not_called()
            capture.assert_called_once()
            self.assertIn("present_probe", capture.call_args.args[0])
            trace.assert_called_once_with(Path(tmp))
            trace.return_value.__enter__.assert_called_once()
            trace.return_value.__exit__.assert_called_once()
            self.assertIs(trace.return_value.__exit__.call_args.args[0], RuntimeError)

    def test_warmup_probe_failure_does_not_replace_gameplay_error(self):
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "capture_combat_failure"), \
                patch.object(walkthrough, "probe", side_effect=OSError("adb failure")):
            with self.assertRaisesRegex(RuntimeError, "Player died"):
                with walkthrough.warmup_present_diagnostic(60):
                    raise RuntimeError("Player died")
            evidence = json.loads(
                (Path(tmp) / "warmup-presentation-diagnostic.json").read_text())
            self.assertEqual(evidence["collector_error"], "adb failure")

    def test_recovery_requires_new_low_displacement_sample(self):
        state = dict(x=-34.6882, z=43.376, yaw=-.2219, center_x=0,
                     center_z=0, radius=110, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        self.assertEqual(route.choose(state)[0], walkthrough.route_movement(state))
        self.assertEqual(route.choose(state)[1]["reason"], "no new movement observation")
        fresh = dict(state, x=-34.67076, z=41.82048, yaw=-.1322,
                     telemetry_epoch_s=105)
        point, evidence = route.choose(fresh)
        self.assertIn("lateral recovery", evidence["reason"])
        self.assertAlmostEqual(evidence["sample_displacement_m"], 1.55562, places=4)
        self.assertNotEqual(point, walkthrough.route_movement(fresh))
        self.assertEqual(route.choose(fresh)[0], point)

    def test_short_batches_accumulate_stationary_window(self):
        state = dict(x=0, z=60, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        for epoch in (100, 101.898, 103.778):
            route.choose(dict(state, telemetry_epoch_s=epoch))
            self.assertIsNone(route.recovery)
        _, evidence = route.choose(dict(state, telemetry_epoch_s=105.658))
        self.assertIn("start lateral recovery", evidence["reason"])
        self.assertAlmostEqual(evidence["displacement_window_s"], 5.658)
        self.assertAlmostEqual(evidence["sample_elapsed_s"], 1.88)
        for epoch in (107.8, 109.7, 111.6, 113.5, 115.4):
            route.choose(dict(state, telemetry_epoch_s=epoch))
        _, evidence = route.choose(dict(state, telemetry_epoch_s=117.3))
        self.assertEqual(evidence["reason"], "failed lateral recovery; reverse course")

    def test_short_window_resets_on_progress_healing_and_gaps(self):
        state = dict(x=0, z=60, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        for change in (dict(x=3), dict(heal_left=2), dict(telemetry_epoch_s=115)):
            with self.subTest(change=change):
                route = walkthrough.RouteControls()
                route.choose(state)
                route.choose(dict(state, telemetry_epoch_s=102))
                reset = dict(state, telemetry_epoch_s=103)
                reset.update(change)
                route.choose(reset)
                route.choose(dict(reset, heal_left=0,
                                  telemetry_epoch_s=reset["telemetry_epoch_s"] + 2))
                self.assertIsNone(route.recovery)

    def test_recovery_keeps_world_course_across_camera_turn_and_expires(self):
        import math
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        route.choose(state)
        point, _ = route.choose(dict(state, telemetry_epoch_s=105))
        turned, evidence = route.choose(dict(
            state, x=3, yaw=math.pi / 2, telemetry_epoch_s=110))
        self.assertEqual(turned, (180, 650 + point[0] - 180))
        self.assertEqual(evidence["reason"], "bounded lateral recovery")
        expired = dict(state, x=6, telemetry_epoch_s=115)
        self.assertEqual(route.choose(expired)[0], walkthrough.route_movement(expired))

    def test_healing_cancels_active_recovery(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        route.choose(state)
        route.choose(dict(state, telemetry_epoch_s=105))
        healing = dict(state, telemetry_epoch_s=110, heal_left=2)
        self.assertEqual(route.choose(healing)[0], walkthrough.route_movement(healing))
        self.assertIsNone(route.recovery)

    def test_zone_margin_prevents_starting_lateral_recovery(self):
        state = dict(x=0, z=85, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        route.choose(state)
        fresh = dict(state, telemetry_epoch_s=105)
        point, evidence = route.choose(fresh)
        self.assertEqual(point, walkthrough.route_movement(fresh))
        self.assertEqual(evidence["zone_margin_m"], 25)
        self.assertIsNone(route.recovery)

    def test_shrinking_zone_cancels_held_recovery_even_on_duplicate_sample(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        for epoch in (105, 110):
            with self.subTest(epoch=epoch):
                route = walkthrough.RouteControls()
                route.choose(state)
                route.choose(dict(state, telemetry_epoch_s=105))
                self.assertIsNotNone(route.recovery)
                edge = dict(state, radius=100, telemetry_epoch_s=epoch)
                point, evidence = route.choose(edge)
                self.assertEqual(point, walkthrough.route_movement(edge))
                self.assertEqual(evidence["zone_margin_m"], 20)
                self.assertIsNone(route.recovery)
                self.assertEqual(route.choose(edge)[0], point)

    def test_r571_outside_zone_position_selects_inward_course(self):
        state = dict(x=-7.583, z=62.972, yaw=0, center_x=-9.378,
                     center_z=7.887, radius=55, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        route.choose(state)
        point, evidence = route.choose(dict(state, telemetry_epoch_s=105))
        self.assertLess(evidence["zone_margin_m"], 0)
        self.assertLess(point[1], 650)
        self.assertEqual(point, walkthrough.route_movement(state))
        self.assertIsNone(route.recovery)

    def test_failed_full_recovery_reverses_once_per_fresh_window(self):
        state = dict(x=-26.80934, z=27.00094, yaw=-.16, center_x=0,
                     center_z=0, radius=110, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        route.choose(state)
        first, _ = route.choose(dict(state, telemetry_epoch_s=105))
        route.choose(dict(state, telemetry_epoch_s=110))
        fresh = dict(state, telemetry_epoch_s=115)
        reverse, evidence = route.choose(fresh)
        self.assertEqual(reverse, (360 - first[0], 1300 - first[1]))
        self.assertEqual(evidence["recovery_displacement_m"], 0)
        self.assertEqual(evidence["reason"], "failed lateral recovery; reverse course")
        self.assertEqual(route.choose(fresh)[0], reverse)
        self.assertEqual(route.choose(dict(state, telemetry_epoch_s=120))[0], reverse)

    def test_failed_recovery_does_not_reverse_after_gap_healing_or_near_zone_edge(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        for changes in (dict(telemetry_epoch_s=130), dict(heal_left=2),
                        dict(radius=100)):
            route = walkthrough.RouteControls()
            route.choose(state)
            route.choose(dict(state, telemetry_epoch_s=105))
            route.choose(dict(state, telemetry_epoch_s=110))
            fresh = dict(state, telemetry_epoch_s=115)
            fresh.update(changes)
            _, evidence = route.choose(fresh)
            self.assertNotIn("reverse", evidence["reason"])

    def test_recovery_excludes_healing_gaps_and_normal_progress(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        for changes in (dict(heal_left=2), dict(telemetry_epoch_s=120),
                        dict(z=75)):
            route = walkthrough.RouteControls()
            route.choose(state)
            fresh = dict(state, telemetry_epoch_s=105)
            fresh.update(changes)
            self.assertEqual(route.choose(fresh)[0], walkthrough.route_movement(fresh))

    def test_recovery_direction_is_lateral_and_not_outward(self):
        import math
        for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
            state = dict(x=0, z=80, yaw=yaw, center_x=0, center_z=0,
                         radius=110, telemetry_epoch_s=100)
            route = walkthrough.RouteControls()
            route.choose(state)
            fresh = dict(state, telemetry_epoch_s=105)
            point, _ = route.choose(fresh)
            lx, lz = (point[0]-180)/100, (point[1]-650)/100
            wx = math.cos(yaw)*lx + math.sin(yaw)*lz
            wz = -math.sin(yaw)*lx + math.cos(yaw)*lz
            self.assertAlmostEqual(abs(wx), 1)
            self.assertAlmostEqual(wz, 0)

    def test_recovery_touch_and_evidence_preserve_fire_aim_and_look(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, telemetry_epoch_s=100)
        route = walkthrough.RouteControls()
        route.choose(state)
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "route_state", return_value=dict(
                    state, telemetry_epoch_s=105)), \
                patch.object(walkthrough, "tap") as tap, \
                patch.object(walkthrough, "adb") as adb:
            walkthrough.combat_cycle((1440, 900), 1, route=route)
            self.assertEqual(tap.call_args_list[0].args[:2], (280, 650))
            self.assertEqual(tap.call_args_list[0].kwargs, {"hold_ms": 2000})
            self.assertEqual([c.args[:2] for c in tap.call_args_list[1:]],
                             [(1150, 635), (1330, 660), (1150, 635)])
            adb.assert_called_once()
            record = json.loads((Path(tmp) / "route-decisions.jsonl").read_text())
            self.assertEqual(record["movement_decision"]["sample_displacement_m"], 0)
            self.assertIn("lateral recovery", record["movement_decision"]["reason"])

    def test_feedback_route_preserves_combat_controls(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True)
        for cycle in range(8):
            with TemporaryDirectory() as tmp, \
                    patch.object(walkthrough, "OUT", Path(tmp)), \
                    patch.object(walkthrough, "route_state", return_value=state), \
                    patch.object(walkthrough, "tap") as tap, \
                    patch.object(walkthrough, "adb") as adb:
                walkthrough.combat_cycle((1440, 900), cycle)
                self.assertEqual(tap.call_args_list[0].args[:2], (180, 550))
                self.assertEqual(tap.call_args_list[0].kwargs, {"hold_ms": 2000})
                self.assertEqual([c.args[:2] for c in tap.call_args_list[1:4]],
                                 [(1150, 635), (1330, 660), (1150, 635)])
                self.assertEqual(tap.call_count, 4)
                adb.assert_called_once()
                record = json.loads((Path(tmp) / "route-decisions.jsonl").read_text())
                self.assertEqual(record["state"], state)
                self.assertEqual(record["supply_action"], "none")

    def test_supply_controls_prioritize_heal_and_reject_reused_sample(self):
        controls = walkthrough.SupplyControls()
        state = dict(health=40, medkits=2, heal_left=0, reload_left=0,
                     ammo=0, reserve=90, telemetry_epoch_s=100)
        self.assertEqual(controls.choose(state)[0], "heal")
        self.assertEqual(controls.choose(state)[0], "none")
        self.assertEqual(controls.choose(dict(state, telemetry_epoch_s=105,
                                             heal_left=2))[0], "none")
        self.assertEqual(controls.choose(dict(state, telemetry_epoch_s=110,
                                             reload_left=1))[0], "none")
        self.assertEqual(controls.choose(dict(state, telemetry_epoch_s=115,
                                             health=100))[0], "reload")
        self.assertEqual(controls.choose(dict(state, telemetry_epoch_s=120,
                                             medkits=0))[0], "reload")
        self.assertEqual(controls.choose(dict(state, telemetry_epoch_s=125,
                                             health=100, ammo=30))[0], "none")
        with self.assertRaises(RuntimeError):
            controls.choose(dict(state, health=float("nan")))

    def test_expired_reload_sample_no_longer_blocks_heal(self):
        controls = walkthrough.SupplyControls()
        state = dict(health=58.5593, medkits=2, heal_left=0,
                     reload_left=0.916666, ammo=0, reserve=90,
                     telemetry_epoch_s=100, telemetry_age_s=0.523)
        self.assertEqual(controls.choose(state)[0], "none")
        state["telemetry_age_s"] = 4.523
        self.assertEqual(controls.choose(state)[0], "heal")
        self.assertEqual(controls.choose(state)[0], "none")
        for age in (-1, 0):
            self.assertEqual(walkthrough.SupplyControls().choose(
                dict(state, telemetry_age_s=age))[0], "none")
        with self.assertRaises(RuntimeError):
            walkthrough.SupplyControls().choose(
                dict(state, telemetry_age_s=float("nan")))

    def test_heal_starts_before_movement_at_observed_declining_health(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True, health=72.4, medkits=2,
                     heal_left=0, reload_left=0, ammo=20, reserve=90,
                     telemetry_epoch_s=100)
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "route_state", return_value=state), \
                patch.object(walkthrough, "tap") as tap, \
                patch.object(walkthrough, "adb"):
            walkthrough.combat_cycle((1440, 900), 0, walkthrough.SupplyControls())
            self.assertEqual(tap.call_args_list[0].args[:2], (1010, 775))
            self.assertEqual(tap.call_args_list[1].kwargs, {"hold_ms": 2000})
            self.assertEqual(tap.call_count, 2)

    def test_active_healing_keeps_moving_and_looking_then_resumes_combat(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True, health=70, medkits=1,
                     heal_left=2, reload_left=0, ammo=20, reserve=90,
                     telemetry_epoch_s=100)
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "route_state", return_value=state), \
                patch.object(walkthrough, "tap") as tap, \
                patch.object(walkthrough, "adb") as adb:
            controls = walkthrough.SupplyControls()
            walkthrough.combat_cycle((1440, 900), 0, controls)
            self.assertEqual(tap.call_count, 1)
            self.assertEqual(tap.call_args.kwargs, {"hold_ms": 2000})
            adb.assert_called_once()
            state.update(heal_left=0, health=100, telemetry_epoch_s=105)
            tap.reset_mock()
            walkthrough.combat_cycle((1440, 900), 1, controls)
            self.assertEqual([c.args[:2] for c in tap.call_args_list[1:]],
                             [(1150, 635), (1330, 660), (1150, 635)])
            records = [json.loads(line) for line in
                       (Path(tmp) / "route-decisions.jsonl").read_text().splitlines()]
            self.assertEqual([r["combat_deferred_for_healing"] for r in records],
                             [True, False])

    def test_reload_wait_uses_short_touch_cycle_then_allows_heal(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True, health=73.48248, medkits=2,
                     heal_left=0, reload_left=1.25, ammo=0, reserve=90,
                     telemetry_epoch_s=100, telemetry_age_s=0)
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "route_state", return_value=state), \
                patch.dict(os.environ, {"ANDROID_MULTITOUCH": "1"}), \
                patch("android_multitouch.run_combat") as run:
            controls = walkthrough.SupplyControls()
            walkthrough.combat_cycle((1440, 900), 0, controls)
            self.assertTrue(run.call_args.kwargs["reloading"])
            self.assertFalse(run.call_args.kwargs["heal"])
            state["telemetry_age_s"] = 2
            walkthrough.combat_cycle((1440, 900), 1, controls)
            self.assertNotIn("reloading", run.call_args.kwargs)
            self.assertTrue(run.call_args.kwargs["heal"])
            records = [json.loads(line) for line in
                       (Path(tmp) / "route-decisions.jsonl").read_text().splitlines()]
            self.assertLess(records[0]["hold_ms"], 1200)
            self.assertEqual([r["supply_action"] for r in records], ["none", "heal"])

    def test_supply_touches_are_exclusive_and_recorded(self):
        for health, action, point in ((40, "heal", (1010, 775)),
                                      (100, "reload", (1170, 775))):
            state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                         radius=110, alive=True, health=health, medkits=2,
                         heal_left=0, reload_left=0, ammo=0, reserve=90,
                         telemetry_epoch_s=100)
            with TemporaryDirectory() as tmp, \
                    patch.object(walkthrough, "OUT", Path(tmp)), \
                    patch.object(walkthrough, "route_state", return_value=state), \
                    patch.object(walkthrough, "tap") as tap, \
                    patch.object(walkthrough, "adb"):
                controls = walkthrough.SupplyControls()
                walkthrough.combat_cycle((1440, 900), 0, controls)
                self.assertEqual(tap.call_count, 2 if action == "heal" else 5)
                self.assertEqual(tap.call_args_list[0 if action == "heal" else -1].args[:2], point)
                tap.reset_mock()
                walkthrough.combat_cycle((1440, 900), 1, controls)
                self.assertEqual(tap.call_count, 1 if action == "heal" else 4)
                records = [json.loads(line) for line in
                           (Path(tmp) / "route-decisions.jsonl").read_text().splitlines()]
                self.assertEqual([r["supply_action"] for r in records], [action, "none"])

    def test_visible_frag_warning_defers_heal_but_allows_reload(self):
        state = dict(health=37, medkits=2, heal_left=0, reload_left=0,
                     ammo=14, reserve=90, telemetry_epoch_s=100,
                     frag_warning=True)
        controls = walkthrough.SupplyControls()
        self.assertEqual(controls.choose(state)[0], "none")
        self.assertIsNone(controls.heal_start_state)
        state.update(ammo=6, telemetry_epoch_s=101)
        self.assertEqual(controls.choose(state)[0], "reload")
        state.update(ammo=30, telemetry_epoch_s=102, frag_warning=False)
        self.assertEqual(controls.choose(state)[0], "heal")

    def test_invalid_frag_warning_fails_instead_of_suppressing_heal(self):
        state = dict(health=37, medkits=2, heal_left=0, reload_left=0,
                     ammo=14, reserve=90, telemetry_epoch_s=100,
                     frag_warning="false")
        with self.assertRaisesRegex(RuntimeError, "grenade warning"):
            walkthrough.SupplyControls().choose(state)

    def test_submitted_heal_defers_combat_across_stale_sample_but_expires(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True, health=70, medkits=1,
                     heal_left=0, reload_left=0, ammo=20, reserve=90,
                     telemetry_epoch_s=100)
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "route_state", return_value=state), \
                patch.object(walkthrough.time, "monotonic", return_value=200) as now, \
                patch.object(walkthrough, "tap") as tap, \
                patch.object(walkthrough, "adb") as adb:
            controls = walkthrough.SupplyControls()
            walkthrough.combat_cycle((1440, 900), 0, controls)
            self.assertEqual(tap.call_count, 2)
            for cycle, timestamp, expected_touches in (
                    (1, 202.5, 1), (2, 203.5, 4)):
                now.return_value = timestamp
                tap.reset_mock()
                adb.reset_mock()
                walkthrough.combat_cycle((1440, 900), cycle, controls)
                self.assertEqual(tap.call_count, expected_touches)
                self.assertEqual(tap.call_args_list[0].kwargs, {"hold_ms": 2000})
                adb.assert_called_once()
            records = [json.loads(line) for line in
                       (Path(tmp) / "route-decisions.jsonl").read_text().splitlines()]
            self.assertEqual([r["combat_deferred_for_healing"] for r in records],
                             [True, True, False])
            self.assertEqual([r["supply_action"] for r in records],
                             ["heal", "none", "none"])

    def test_pending_heal_blocks_new_stale_sample_supply_touches(self):
        state = dict(health=70, medkits=1, heal_left=0, reload_left=0,
                     ammo=5, reserve=90, telemetry_epoch_s=100)
        controls = walkthrough.SupplyControls()
        with patch.object(walkthrough.time, "monotonic", return_value=200) as now:
            self.assertEqual(controls.choose(state)[0], "heal")
            controls.heal_submitted()
            now.return_value = 202
            state["telemetry_epoch_s"] = 101
            self.assertEqual(controls.choose(state),
                             ("none", "submitted heal awaiting completion"))
            state["health"] = 100
            self.assertEqual(controls.choose(state)[0], "none")
            # A suppressed action must not consume the sample: after the
            # bounded pause ends, its reload decision remains available.
            now.return_value = 203.5
            self.assertEqual(controls.choose(state)[0], "reload")

    def test_post_input_canceled_heal_releases_pending_guard(self):
        controls = walkthrough.SupplyControls()
        state = dict(health=58, medkits=1, heal_left=0, reload_left=0,
                     ammo=20, reserve=90, telemetry_epoch_s=100)
        with patch.object(walkthrough.time, "monotonic", return_value=200) as now:
            self.assertEqual(controls.choose(state)[0], "heal")
            controls.heal_submitted()
            state.update(telemetry_epoch_s=101, health=35)
            controls.observe_post_input(state, 102)
            self.assertTrue(controls.healing(state))
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(telemetry_epoch_s=102, heal_left=2)
            controls.observe_post_input(state, 102)
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(telemetry_epoch_s=103, heal_left=0)
            controls.observe_post_input(state, 102)
            self.assertFalse(controls.healing(state))
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(ammo=0)
            self.assertEqual(controls.choose(state)[0], "reload")
            state.update(ammo=20, telemetry_epoch_s=104)
            now.return_value = 207.9
            controls.observe_post_input(state, 102)
            self.assertEqual(controls.choose(state)[0], "none")
            now.return_value = 208
            self.assertEqual(controls.choose(state)[0], "heal")
            self.assertEqual(controls.choose(state)[0], "none")

    def test_completed_heal_with_damage_does_not_delay_next_heal(self):
        controls = walkthrough.SupplyControls()
        state = dict(health=58, medkits=2, heal_left=0, reload_left=0,
                     ammo=20, reserve=90, telemetry_epoch_s=100)
        with patch.object(walkthrough.time, "monotonic", return_value=200):
            self.assertEqual(controls.choose(state)[0], "heal")
            controls.heal_submitted()
            state.update(health=35, medkits=1, telemetry_epoch_s=105)
            controls.observe_post_input(state, 102)
            self.assertEqual(controls.heal_retry_after, 0)
            self.assertEqual(controls.choose(state)[0], "heal")

    def test_recent_damage_defers_first_heal_without_blocking_reload(self):
        controls = walkthrough.SupplyControls()
        state = dict(health=100, medkits=2, heal_left=0, reload_left=0,
                     ammo=22, reserve=90, telemetry_epoch_s=100)
        with patch.object(walkthrough.time, "monotonic", return_value=200) as now:
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(health=86.604, telemetry_epoch_s=103)
            now.return_value = 203
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(health=77.404, ammo=6, telemetry_epoch_s=106)
            now.return_value = 206
            self.assertEqual(controls.choose(state)[0], "reload")
            self.assertEqual(controls.heal_retry_after, 209.5)
            state.update(ammo=30, telemetry_epoch_s=109)
            now.return_value = 209
            self.assertEqual(controls.choose(state)[0], "none")
            now.return_value = 209.4
            self.assertEqual(controls.choose(state)[0], "none")
            # Reused samples must not extend the damage cooldown.
            self.assertEqual(controls.heal_retry_after, 209.5)
            now.return_value = 209.5
            self.assertEqual(controls.choose(state)[0], "heal")

    def test_r1066_damage_free_window_allows_first_heal(self):
        # Recorded health/elapsed values; this checks input policy only.
        controls = walkthrough.SupplyControls()
        state = dict(health=90.8, medkits=2, heal_left=0, reload_left=0,
                     ammo=30, reserve=90, telemetry_epoch_s=100,
                     frag_warning=False)
        with patch.object(walkthrough.time, "monotonic", return_value=200) as now:
            controls.choose(state)
            state.update(health=75.62, telemetry_epoch_s=102.118,
                         reload_left=1)
            now.return_value = 202.118
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(telemetry_epoch_s=104.194, reload_left=0)
            now.return_value = 204.194
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(telemetry_epoch_s=106.287)
            now.return_value = 206.287
            self.assertEqual(controls.choose(state)[0], "heal")

    def test_r1068_heals_in_quiet_window_before_renewed_fire(self):
        controls = walkthrough.SupplyControls()
        state = dict(health=90.8, medkits=2, heal_left=0, reload_left=0,
                     ammo=14, reserve=90, telemetry_epoch_s=100,
                     frag_warning=False)
        with patch.object(walkthrough.time, "monotonic", return_value=200) as now:
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(health=81.6, ammo=10, telemetry_epoch_s=102.296)
            now.return_value = 202.296
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(ammo=6, telemetry_epoch_s=105.226)
            now.return_value = 205.226
            self.assertEqual(controls.choose(state)[0], "reload")
            state.update(reload_left=0.466, telemetry_epoch_s=107.537)
            now.return_value = 207.537
            self.assertEqual(controls.choose(state)[0], "none")
            state.update(ammo=30, reload_left=0, telemetry_epoch_s=109.460,
                         frag_warning=True)
            now.return_value = 209.460
            self.assertEqual(controls.choose(state)[0], "none")
            state["frag_warning"] = False
            self.assertEqual(controls.choose(state)[0], "heal")
            controls.heal_submitted()
            state.update(telemetry_epoch_s=110)
            self.assertEqual(controls.choose(state)[0], "none")

    def test_route_turns_inward_independent_of_camera(self):
        import math
        for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
            for dx, dz in ((80, 0), (-80, 0), (0, 80), (0, -80)):
                state = dict(x=dx+12, z=dz-9, yaw=yaw, center_x=12,
                             center_z=-9, radius=100)
                x, y = walkthrough.route_movement(state)
                lx, lz = (x-180)/100, (y-650)/100
                wx = math.cos(yaw)*lx + math.sin(yaw)*lz
                wz = -math.sin(yaw)*lx + math.cos(yaw)*lz
                self.assertLess(wx*dx + wz*dz, -79)
        with self.assertRaises(RuntimeError):
            walkthrough.route_movement(dict(state, radius=float("nan")))

    def test_route_keeps_lateral_motion_across_observed_radial_overshoot(self):
        # r611 travelled between ~32m and ~65m on consecutive samples;
        # neither observation should cause a pure radial reversal.
        for distance in (32, 65):
            state = dict(x=0, z=distance, yaw=0, center_x=0,
                         center_z=0, radius=110)
            x, y = walkthrough.route_movement(state)
            self.assertLess(x, 140)
            if distance < 49.5:
                self.assertGreater(y, 650)
            else:
                self.assertLess(y, 650)
        state["z"] = 86
        self.assertEqual(walkthrough.route_movement(state), (180, 550))

    def test_route_rejects_missing_stale_and_dead_telemetry(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True)
        def line(data):
            return ("100.5 1 1 I godot: ANDROID_GAMEPLAY route_json=" +
                    json.dumps(data)).encode()
        for output in (b"\nANDROID_ROUTE_CLOCK=101\n",
                       line(state) + b"\nANDROID_ROUTE_CLOCK=114\n",
                       line(dict(state, alive=False)) + b"\nANDROID_ROUTE_CLOCK=101\n"):
            with patch.object(walkthrough, "adb", return_value=output), \
                    self.assertRaises(RuntimeError):
                walkthrough.route_state()
        with patch.object(walkthrough, "adb",
                          return_value=line(state) + b"\nANDROID_ROUTE_CLOCK=101\n") as read:
            self.assertEqual(walkthrough.route_state(), dict(
                state, telemetry_epoch_s=100.5, device_observed_epoch_s=101,
                telemetry_age_s=0.5))
            read.assert_called_once_with(
                "shell", walkthrough.ROUTE_OBSERVATION_COMMAND)
        with patch.object(walkthrough, "adb",
                          side_effect=[line(state) + b"\nANDROID_ROUTE_CLOCK=101\n",
                                       line(state) + b"\nANDROID_ROUTE_CLOCK=103\n"]):
            first = walkthrough.route_state()
            second = walkthrough.route_state()
        self.assertEqual(first["telemetry_epoch_s"], second["telemetry_epoch_s"])
        self.assertEqual(first["x"], second["x"])
        self.assertEqual(second["telemetry_age_s"], 2.5)

    def test_route_rejects_missing_or_corrupt_clock(self):
        log = b'100.5 1 1 I godot: ANDROID_ROUTE route_json={"alive":true}\n'
        for suffix in (b"", b"ANDROID_ROUTE_CLOCK=", b"ANDROID_ROUTE_CLOCK=nan",
                       b"ANDROID_ROUTE_CLOCK=inf", b"ANDROID_ROUTE_CLOCK=101\nnoise"):
            with self.subTest(suffix=suffix), \
                    patch.object(walkthrough, "adb", return_value=log + suffix), \
                    self.assertRaisesRegex(RuntimeError, "device clock"):
                walkthrough.route_state()

    def test_initial_capture_waits_for_collector_result(self):
        supplies = walkthrough.SupplyControls()
        controls = walkthrough.RouteControls()
        executor = MagicMock()
        pending = MagicMock()
        pending.done.side_effect = [False, True]
        order = []
        pending.result.side_effect = lambda: order.append("result") or {"valid": True}

        def submit(function, package, output, seconds, ready):
            order.append("seed")
            ready.set()
            return pending

        executor.__enter__.return_value.submit.side_effect = submit
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "initial_route",
                             side_effect=lambda *a, **kw: order.append("route")) as route, \
                patch.object(walkthrough, "combat_cycle") as combat, \
                patch.object(walkthrough, "capture",
                             side_effect=lambda *a: order.append("capture")):
            walkthrough.measure_initial_route((1440, 900), supplies, controls)
            diagnostic = json.loads((Path(tmp) / "initial-route-diagnostic.json").read_text())
        self.assertEqual(order, ["seed", "route", "result", "capture"])
        route.assert_called_once_with((1440, 900), screenshots=False)
        self.assertFalse(diagnostic["acceptance"])
        combat.assert_called_once_with((1440, 900), 0, supplies, controls)

    def test_long_measurement_preserves_initial_route_obstacle_observation(self):
        # r631's phase transition discarded this sample and delayed escape
        # until another five-second telemetry emission, while HP fell rapidly.
        controls = walkthrough.RouteControls()
        state = dict(x=-33.360916, z=40.02276, yaw=-0.132596,
                     center_x=0, center_z=0, radius=110, heal_left=0,
                     telemetry_epoch_s=1790725735.471)
        controls.choose(state)
        next_state = dict(state, z=38.680385,
                          telemetry_epoch_s=1790725740.664)
        supplies = walkthrough.SupplyControls()
        supplies.heal_pending_until = float("inf")
        decisions = []

        def combat(size, cycle, supplied, routed):
            decisions.append(routed.choose(next_state)[1])
            self.assertTrue(supplied.healing(next_state))

        executor = MagicMock()
        pending = executor.__enter__.return_value.submit.return_value
        pending.done.side_effect = [False, True]
        pending.result.return_value = {}
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "wait_for_combat_seed"), \
                patch.object(walkthrough, "combat_cycle", side_effect=combat), \
                patch.object(walkthrough, "adb", return_value=b""):
            walkthrough.measure_combat((1440, 900), 300, 0, supplies, controls)
        self.assertEqual(decisions[0]["reason"],
                         "fresh low displacement; start lateral recovery")
        self.assertAlmostEqual(decisions[0]["sample_displacement_m"], 1.342375)

    def test_measurement_seed_gameplay_preserves_cycle_and_control_state(self):
        supplies = walkthrough.SupplyControls()
        controls = walkthrough.RouteControls()
        cycles = []

        def combat(size, cycle, supplied, routed):
            self.assertIs(supplied, supplies)
            self.assertIs(routed, controls)
            cycles.append(cycle)

        def seed(pending, ready, on_wait):
            on_wait()

        executor = MagicMock()
        pending = executor.__enter__.return_value.submit.return_value
        pending.done.side_effect = [False, True]
        pending.result.return_value = {}
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "wait_for_combat_seed", side_effect=seed), \
                patch.object(walkthrough, "combat_cycle", side_effect=combat), \
                patch.object(walkthrough, "adb", return_value=b""):
            report = walkthrough.measure_combat((1440, 900), 300, 0, supplies, controls)
        self.assertEqual(cycles, [0, 1])
        self.assertEqual(report["seed_startup_cycles"], 1)
        self.assertEqual(report["measured_cycles"], 1)

    def test_initial_route_disables_every_screenshot(self):
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "tap") as tap, \
                patch.object(walkthrough, "adb") as adb, \
                patch.object(walkthrough.time, "sleep"), \
                patch.object(walkthrough, "capture") as capture:
            walkthrough.initial_route((1440, 900), screenshots=False)
            events = [json.loads(line) for line in
                      (Path(tmp) / "phase-commands.jsonl").read_text().splitlines()]
        capture.assert_not_called()
        self.assertEqual(tap.call_count, 4)
        adb.assert_called_once()
        self.assertEqual([event["name"] for event in events],
                         ["initial-solo", "initial-fire", "initial-look"])
        self.assertTrue(all(event["success"] for event in events))

    def test_failed_seed_does_not_start_route(self):
        executor = MagicMock()
        pending = executor.__enter__.return_value.submit.return_value
        pending.done.return_value = True
        pending.result.return_value = {"valid": False, "error": "no layer"}
        with patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "initial_route") as route:
            with self.assertRaisesRegex(RuntimeError, "could not seed"):
                walkthrough.measure_initial_route((1440, 900))
        route.assert_not_called()

    def test_input_continues_past_old_six_cycle_limit(self):
        executor = MagicMock()
        pending = executor.__enter__.return_value.submit.return_value
        pending.done.side_effect = [False] * 9 + [True]
        pending.result.return_value = {"valid": False, "error": "synthetic failure"}
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "wait_for_combat_seed"), \
                patch.object(walkthrough, "combat_cycle") as combat, \
                patch.object(walkthrough, "adb", return_value=b"warmup diagnostics"):
            result = walkthrough.measure_combat((1440, 900), 300, 0)
        self.assertEqual(combat.call_count, 9)
        self.assertEqual(result["measured_cycles"], 9)
        self.assertFalse(result["present_probe"]["valid"])
        self.assertEqual(executor.__enter__.return_value.submit.call_args.args[-1], 300)

    def test_slow_boundary_snapshot_keeps_shared_gameplay_active(self):
        released = walkthrough.Event()
        executor = MagicMock()
        pending = executor.__enter__.return_value.submit.return_value
        pending.done.side_effect = [False, True]
        pending.result.return_value = {}
        supplies, route = object(), object()
        def device(*args):
            if args == ("logcat", "-d"):
                if not released.wait(2):
                    raise AssertionError("Snapshot blocked input")
                return b"preserved warmup"
            return b""
        def play(*args):
            released.set()
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "wait_for_combat_seed"), \
                patch.object(walkthrough, "combat_cycle", side_effect=play) as combat, \
                patch.object(walkthrough, "adb", side_effect=device):
            result = walkthrough.measure_combat((1440, 900), 300, 0, supplies, route)
            self.assertEqual((Path(tmp) / "warmup.logcat").read_bytes(), b"preserved warmup")
            boundary = json.loads((Path(tmp) / "combat-boundary.json").read_text())
        self.assertEqual(result["boundary_cycles"], 1)
        self.assertEqual(boundary["completed_cycles"], 1)
        self.assertEqual(result["measured_cycles"], 1)
        self.assertEqual([c.args[1] for c in combat.call_args_list], [0, 1])
        self.assertTrue(all(c.args[2:] == (supplies, route) for c in combat.call_args_list))

    def test_background_boundary_propagates_io_timeout(self):
        def failed():
            raise TimeoutError("device I/O failed")
        with self.assertRaisesRegex(TimeoutError, "device I/O failed"):
            walkthrough.combat_background_work(failed, lambda: self.fail("Unexpected input"))

    def test_background_boundary_joins_writer_on_gameplay_failure(self):
        released, finished = walkthrough.Event(), walkthrough.Event()
        def snapshot():
            released.wait(2)
            finished.set()
        def failed_play():
            released.set()
            raise RuntimeError("Player died")
        with self.assertRaisesRegex(RuntimeError, "Player died"):
            walkthrough.combat_background_work(snapshot, failed_play)
        self.assertTrue(finished.is_set())

    def test_warmup_is_active_and_excluded_from_measured_cycles(self):
        executor = MagicMock()
        pending = executor.__enter__.return_value.submit.return_value
        pending.done.side_effect = [False, True]
        pending.result.return_value = {}
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "wait_for_combat_seed"), \
                patch.object(walkthrough.time, "monotonic", side_effect=[0, 0, 6, 12, 12, 18]), \
                patch.object(walkthrough, "combat_cycle") as combat, \
                patch.object(walkthrough, "adb", return_value=b"SCRIPT ERROR warmup") as adb:
            result = walkthrough.measure_combat((1440, 900), 300, 10)
            self.assertEqual((Path(tmp) / "warmup.logcat").read_bytes(),
                             b"SCRIPT ERROR warmup")
        self.assertEqual([call.args[1] for call in combat.call_args_list], [0, 1, 2])
        self.assertEqual(result["measured_cycles"], 1)
        self.assertEqual(result["warmup_elapsed_seconds"], 12)
        self.assertEqual([call.args for call in adb.call_args_list],
                         [("logcat", "-d"),
                          ("shell", "log", "-t", "FPSProbe", result["log_marker"]),
                          ("shell", "log", "-t", "FPSProbe", result["log_end_marker"])])

    def test_measurement_log_boundary_excludes_warmup_and_requires_marker(self):
        logs = ("ANDROID_PERF fps=12 p95_ms=80\n"
                "I FPSProbe: unique_marker\n"
                "ANDROID_PERF fps=59 p95_ms=17\n")
        self.assertEqual(walkthrough.measurement_logs(logs, "unique_marker"),
                         "ANDROID_PERF fps=59 p95_ms=17\n")
        with self.assertRaisesRegex(RuntimeError, "marker missing"):
            walkthrough.measurement_logs(logs, "lost_marker")

    def test_end_boundary_retains_in_window_death_and_excludes_cleanup(self):
        logs = ("I adbd: shell log -t FPSProbe start\n"
                "warmup\nI FPSProbe: start\n"
                "ANDROID_GAMEPLAY alive=false\n"
                "I adbd: shell log -t FPSProbe end\n"
                "I FPSProbe: end\ncleanup death\n")
        bounded = walkthrough.measurement_logs(logs, "start", "end")
        self.assertIn("alive=false", bounded)
        self.assertNotIn("cleanup death", bounded)
        self.assertNotIn("warmup", bounded)
        with self.assertRaisesRegex(RuntimeError, "end marker"):
            walkthrough.measurement_logs(logs, "start", "missing")
        with self.assertRaisesRegex(RuntimeError, "out of order"):
            walkthrough.measurement_logs(logs, "end", "start")

    def test_measurement_reuses_fresh_warmup_route_until_next_emission(self):
        state = dict(x=0, z=80, yaw=0, center_x=0, center_z=0,
                     radius=110, alive=True)
        log = [("100.5 1 1 I godot: ANDROID_GAMEPLAY route_json=" +
                json.dumps(state)).encode()]

        def device(*args):
            if args == ("logcat", "-c"):
                log.clear()
                return b""
            if args[:2] == ("logcat", "-d"):
                return b"\n".join(log)
            if args == ("shell", walkthrough.ROUTE_OBSERVATION_COMMAND):
                return b"\n".join(log) + b"\nANDROID_ROUTE_CLOCK=103\n"
            return b""

        executor = MagicMock()
        pending = executor.__enter__.return_value.submit.return_value
        pending.done.side_effect = [False, True]
        pending.result.return_value = {}
        with TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough, "ThreadPoolExecutor", return_value=executor), \
                patch.object(walkthrough, "wait_for_combat_seed"), \
                patch.object(walkthrough, "adb", side_effect=device), \
                patch.object(walkthrough, "tap") as tap:
            result = walkthrough.measure_combat((1440, 900), 60, 0)
            decisions = json.loads((Path(tmp) / "route-decisions.jsonl").read_text())
        self.assertEqual(result["measured_cycles"], 1)
        self.assertEqual(decisions["state"]["telemetry_age_s"], 2.5)
        self.assertTrue(tap.called)


if __name__ == "__main__":
    unittest.main()
