"""Deterministic touch walkthrough, executed on a Device Farm test host."""
import os
import json
import math
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from concurrent.futures import Future, ThreadPoolExecutor, TimeoutError as FutureTimeout
from contextlib import contextmanager
from threading import Event, Thread

from android_present_intervals import probe
from android_multitouch import combat_events, combat_look_points, route_combat_lead_ms
from android_system_trace import system_trace
from android_cpu_sample import cpu_sample

OUT = Path(os.environ["DEVICEFARM_LOG_DIR"])
PACKAGE = "org.ironmeridian.game"
PROFILE_GAME = os.environ.get("ANDROID_PROFILE_GAME") == "1"

# Filter on device with Android toybox utilities. Preserve the newest matching
# line even if its JSON is corrupt or reports death; parsing must fail closed.
# Android's mksh supports pipefail. Stream the dump: passing it as one printf
# argument exceeds Android's argv limit on busy devices. Isolate pipefail from
# the surrounding touch command and preserve logcat errors through the filter.
# Reject unrelated tags before logcat formats/writes them on each touch cycle.
# Keep the message filter below: Godot also emits unrelated gameplay records.
ROUTE_OBSERVATION_COMMAND = (
    "(set -o pipefail && logcat -d -v epoch -t 2000 'godot:I' '*:S' | "
    "grep -E ' I godot *: ANDROID_(ROUTE|GAMEPLAY) route_json=' | "
    "tail -n 1) && "
    "printf '\\nANDROID_ROUTE_CLOCK=' && date +%s.%N"
)


@contextmanager
def phase(name):
    """Host bounds only; logcat emission can lag the engine event."""
    event = {"name": name, "host_start_monotonic_s": time.monotonic(),
             "success": False}
    try:
        yield
        event["success"] = True
    finally:
        event["host_end_monotonic_s"] = time.monotonic()
        with (OUT / "phase-commands.jsonl").open("a") as stream:
            stream.write(json.dumps(event) + "\n")


def adb(*args):
    if args[:2] != ("shell", "input"):
        return subprocess.check_output(["adb", *args])
    # Same host monotonic clock as the SurfaceFlinger collector. These bounds
    # describe command execution, not device input delivery or frame causation.
    event = {"command": list(args), "host_start_monotonic_s": time.monotonic(),
             "success": False}
    try:
        output = subprocess.check_output(["adb", *args])
        event["success"] = True
        return output
    finally:
        event["host_end_monotonic_s"] = time.monotonic()
        with (OUT / "input-commands.jsonl").open("a") as stream:
            stream.write(json.dumps(event) + "\n")


def capture(name):
    event = {"name": name, "host_start_monotonic_s": time.monotonic(), "success": False}
    try:
        image = adb("exec-out", "screencap", "-p")
        event["success"] = True
    finally:
        event["host_end_monotonic_s"] = time.monotonic()
        with (OUT / "screenshot-commands.jsonl").open("a") as stream:
            stream.write(json.dumps(event) + "\n")
    (OUT / (name + ".png")).write_bytes(image)
    return int.from_bytes(image[16:20], "big"), int.from_bytes(image[20:24], "big")


def tap(x, y, size, hold_ms=0):
    width, height = size
    scale = min(width / 1440, height / 900)
    px = round((width - 1440 * scale) / 2 + x * scale)
    py = round((height - 900 * scale) / 2 + y * scale)
    if hold_ms:
        adb("shell", "input", "swipe", str(px), str(py), str(px), str(py), str(hold_ms))
    else:
        adb("shell", "input", "tap", str(px), str(py))


def debug_compatibility_button(xml):
    """Only acknowledge the Android debug-app ELF warning, never arbitrary UI."""
    root = ET.fromstring(xml)
    nodes = list(root.iter("node"))
    system_text = " ".join(n.get("text", "") for n in nodes
                           if n.get("package") == "android")
    if not all(text in system_text for text in (
            "debuggable app", "16 KB", "ELF alignment check failed",
            "libgodot_android.so")):
        return None
    buttons = [n for n in nodes if n.get("package") == "android"
               and n.get("resource-id") in ("android:id/button1", "android:id/button2")
               and n.get("text", "").upper() == "OK"
               and n.get("enabled") == "true"
               and n.get("clickable") == "true"]
    if len(buttons) != 1:
        raise RuntimeError("Debug compatibility warning has no unambiguous OK button")
    bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
                          buttons[0].get("bounds", ""))
    if not bounds:
        raise RuntimeError("Invalid debug compatibility button bounds")
    left, top, right, bottom = map(int, bounds.groups())
    if right <= left or bottom <= top:
        raise RuntimeError("Empty debug compatibility button bounds")
    return ((left + right) // 2, (top + bottom) // 2)


def dismiss_debug_compatibility_warning():
    def hierarchy(name):
        adb("shell", "uiautomator", "dump", "/sdcard/iron-debug-window.xml")
        xml = adb("exec-out", "cat", "/sdcard/iron-debug-window.xml")
        (OUT / name).write_bytes(xml)
        return xml

    report = {"diagnostic_only": True, "button": None, "dismissed": False}
    try:
        button = debug_compatibility_button(hierarchy("debug-compatibility-before.xml"))
        report["button"] = button
        if button is not None:
            capture("debug-compatibility-before")
            adb("shell", "input", "tap", str(button[0]), str(button[1]))
            time.sleep(2)
            if debug_compatibility_button(hierarchy("debug-compatibility-after.xml")):
                raise RuntimeError("Debug compatibility warning remains after OK")
            report["dismissed"] = True
    except Exception as exc:
        report["error"] = str(exc)
        raise
    finally:
        (OUT / "debug-compatibility.json").write_text(json.dumps(report, indent=2))


def route_state(output=None, elapsed=0):
    """Require fresh device telemetry; older APKs must not silently walk blind."""
    # Sample time after dumping logs in the same device shell to avoid another
    # transport round trip between observation and the next movement command.
    if output is None:
        output = adb("shell", ROUTE_OBSERVATION_COMMAND).decode(errors="replace")
    log, marker, clock_value = output.rpartition("\nANDROID_ROUTE_CLOCK=")
    if not marker or not re.fullmatch(r"[0-9]+(?:\.[0-9]{9})?\s*", clock_value):
        raise RuntimeError("Missing or malformed device clock; stopping touch route")
    device_now = float(clock_value) + elapsed
    lines = [line for line in log.splitlines()
             if ("ANDROID_ROUTE " in line or "ANDROID_GAMEPLAY " in line)
             and " route_json=" in line]
    if not lines:
        raise RuntimeError("Missing route telemetry: rebuild the candidate APK")
    line = lines[-1]
    timestamp = float(line.split()[0])
    if not -1 <= device_now - timestamp <= 12:
        raise RuntimeError("Stale gameplay telemetry; stopping touch route")
    try:
        state = json.loads(line.split(" route_json=", 1)[1])
    except json.JSONDecodeError as error:
        raise RuntimeError(
            "Malformed route telemetry; stopping touch route (rebuild APK if truncated)"
        ) from error
    if state.get("alive") is not True:
        raise RuntimeError("Player died; stopping performance route")
    # Route samples arrive every second (five seconds on older APKs). Preserve age so repeated
    # route decisions cannot be mistaken for independent observations of no motion.
    # Retain support for whole-second clocks in archived diagnostic output.
    state["telemetry_epoch_s"] = timestamp
    state["device_observed_epoch_s"] = device_now
    state["telemetry_age_s"] = device_now - timestamp
    return state


def post_look_observation(output):
    """Wait for a route sample recorded after the completed look command."""
    started = time.monotonic()
    state = route_state(output)
    # Prefer the barrier immediately after injection, before logcat collection.
    # Requiring a sample after collection discards already fresh observations.
    # Archived output falls back to its conservative observation-clock barrier.
    clock_value = output.rpartition("\nANDROID_ROUTE_CLOCK=")[2].strip()
    barrier = state["device_observed_epoch_s"]
    if "ANDROID_LOOK_END_CLOCK=" in output:
        clocks = [line.split("=", 1)[1] for line in output.splitlines()
                  if line.startswith("ANDROID_LOOK_END_CLOCK=")]
        if len(clocks) != 1 or not re.fullmatch(r"\d+\.\d{9}", clocks[0]):
            raise RuntimeError("Malformed post-look device clock")
        clock_value = clocks[0]
        barrier = float(clock_value)
        if not 0 <= state["device_observed_epoch_s"] - barrier <= 12:
            raise RuntimeError("Invalid post-look device clock age")
    threshold = barrier + (
        .001 if "." in clock_value else 1)
    polls = 0
    while state["telemetry_epoch_s"] < threshold:
        if time.monotonic() - started >= 3:
            error = RuntimeError("No post-look route sample within 3s; stopping touch route")
            error.raw_observation = output
            raise error
        # The initial collection already consumed device/transport time. Read
        # again immediately; only back off if that read is still stale.
        if polls:
            time.sleep(.1)
        output = adb("shell", ROUTE_OBSERVATION_COMMAND).decode(errors="replace")
        try:
            state = route_state(output)
        except RuntimeError as error:
            error.raw_observation = output
            raise
        polls += 1
    return output, state, {
        "minimum_telemetry_epoch_s": threshold,
        "polls": polls,
        "host_wait_s": time.monotonic() - started,
    }


def route_movement(state):
    """Circle inside the current zone using ordinary camera-relative joystick input."""
    values = [float(state[key]) for key in
              ("x", "z", "yaw", "center_x", "center_z", "radius")]
    if not all(math.isfinite(value) for value in values) or values[-1] <= 0:
        raise RuntimeError("Invalid route geometry")
    x, z, yaw, cx, cz, radius = values
    dx, dz = x - cx, z - cz
    distance = math.hypot(dx, dz)
    # Stay well inside the boundary: telemetry is periodic and inputs take time.
    orbit = max(0, min(radius * .45, radius - 25))
    if distance < 1:
        wx, wz = 1.0, 0.0
    else:
        # Five-second telemetry samples observed ~30m travel on Android.
        # A 10m correction band sent alternating full inward/outward inputs
        # across the orbit. Keep a tangential course through that travel band.
        # Close to the boundary, retain the direct inward escape.
        radial = (-1 if radius - distance <= 25 else
                  max(-1, min(1, (orbit - distance) / 30)))
        tangent = max(0, 1 - abs(radial))
        wx = (radial * dx - tangent * dz) / distance
        wz = (radial * dz + tangent * dx) / distance
    length = math.hypot(wx, wz)
    wx, wz = wx / length, wz / length
    # Inverse of Actor's Basis(Vector3.UP, yaw) transform.
    local_x = math.cos(yaw) * wx - math.sin(yaw) * wz
    local_z = math.sin(yaw) * wx + math.cos(yaw) * wz
    return round(180 + 100 * local_x), round(650 + 100 * local_z)


# r1148/r1149: swept scene capsule includes the actor radius plus 1m
# observation/arrival tolerance. These are test inputs, not gameplay changes.
BUILDING_ROUTE_POINTS = ((-31.0, 49.0), (-54.0, 49.0), (-54.0, 24.0),
                         (-28.0, 19.0), (-21.0, 26.0), (-21.0, 30.0),
                         (-28.0, 38.0))
BUILDING_ROUTE_ENTRY = (0.0, 64.3190231323242)


def on_route_segment(x, z, start, finish):
    dx, dz = finish[0] - start[0], finish[1] - start[1]
    t = max(0, min(1, ((x - start[0]) * dx + (z - start[1]) * dz) /
                   (dx * dx + dz * dz)))
    return math.hypot(x - start[0] - t * dx, z - start[1] - t * dz) <= 1


class RouteControls:
    """Keep a bounded world-space lateral course after observed low displacement."""

    def __init__(self):
        self.previous = None
        self.displacement_window = None
        self.recovery = None
        self.contact_recovery_epoch = None
        self.pending_observation = None
        self.clearance = None
        self.building_route = os.environ.get("ANDROID_BUILDING_ROUTE") == "1"
        self.waypoint_index = None
        self.waypoint_direction = 1
        self.waypoint_evidence = None
        self.corner_arrivals = [0] * len(BUILDING_ROUTE_POINTS)

    def route_point(self, state):
        point = route_movement(state)  # Validate geometry, retain zone fallback.
        self.waypoint_evidence = None
        arrived_corner = None
        if not self.building_route:
            return point
        corners = BUILDING_ROUTE_POINTS
        count = len(corners)
        x, z, cx, cz, radius = (float(state[k]) for k in
                                ("x", "z", "center_x", "center_z", "radius"))
        safe = [radius - math.hypot(px - cx, pz - cz) > 25
                for px, pz in corners]
        # Only connect along a swept segment's 1m corridor. The former
        # exterior-side heuristic incorrectly allowed paths through rear props.
        def reachable(i):
            return (on_route_segment(x, z, corners[(i - 1) % count], corners[i]) or
                    on_route_segment(x, z, corners[i], corners[(i + 1) % count]) or
                    (i == 0 and on_route_segment(
                        x, z, BUILDING_ROUTE_ENTRY, corners[0])))

        eligible = [i for i in range(count) if safe[i] and reachable(i) and
                    (safe[(i - 1) % count] or safe[(i + 1) % count])]
        if radius - math.hypot(x - cx, z - cz) <= 25 or not eligible:
            self.waypoint_index = None
            self.waypoint_evidence = {"fallback": "no reachable safe building segment"}
            return point
        if self.waypoint_index not in eligible:
            self.waypoint_index = min(eligible, key=lambda i:
                math.hypot(corners[i][0] - x, corners[i][1] - z))
        px, pz = corners[self.waypoint_index]
        # r1132 turned 1.915m early at the rear/east corner and hit a wall.
        # Reach within 1m before turning to preserve more collision clearance.
        if math.hypot(px - x, pz - z) <= 1:
            arrived_corner = self.waypoint_index
            self.corner_arrivals[arrived_corner] += 1
            next_index = (self.waypoint_index + self.waypoint_direction) % count
            if not safe[next_index]:
                self.waypoint_direction *= -1
                next_index = (self.waypoint_index + self.waypoint_direction) % count
            self.waypoint_index = next_index
            px, pz = corners[self.waypoint_index]
        dx, dz = px - x, pz - z
        distance = math.hypot(dx, dz)
        yaw = float(state["yaw"])
        self.waypoint_evidence = {
            "index": self.waypoint_index, "target_xz": [px, pz],
            "direction": self.waypoint_direction, "safe_corners": safe,
            # Proximity observations only: repeats do not prove identical
            # camera views, completed laps, or obstacle-free traversal.
            "arrived_corner": arrived_corner,
            "corner_arrivals": list(self.corner_arrivals),
            "distance_m": distance, "validated_cover": False}
        # Match the distance-dependent combat hold, rather than slowing the
        # stick for a 1474ms hold when short legs only receive 974ms (r960).
        # Supply/recovery holds are shorter; retain a conservative 10m/s cap.
        movement_budget = (route_combat_lead_ms(distance) + 724) / 100
        # Budget the actual stick hold when combat_cycle has planned supply
        # inputs. r1125 used a 974ms combat budget during a 250ms healing
        # pulse, unnecessarily slowing an already slow healing walk.
        # Keep the legacy budget for sequential input and standalone callers.
        supply_options = getattr(self, "movement_supply_options", None)
        if supply_options is not None:
            planned = combat_events(
                (1440, 900), (180, 650), 0, route_feedback=True,
                route_distance_m=distance, **supply_options)
            movement_budget = next(
                t for t, action, _ in planned if action == 1) / 100
        command_strength = min(1.0, distance / movement_budget)
        # MobileControls normalizes by 105px; Input.get_vector then remaps
        # the 0.12 circular deadzone. Invert both for short legs so a requested
        # movement fraction is not reduced a second time. Keep the established
        # 100px full-stick limit and the conservative movement budget.
        strength = min(1.0, 1.05 * (0.12 + 0.88 * command_strength))
        self.waypoint_evidence["stick_scale"] = strength
        self.waypoint_evidence["requested_command_strength"] = command_strength
        self.waypoint_evidence["movement_budget_m"] = movement_budget
        return (round(180 + 100 * strength * (math.cos(yaw) * dx - math.sin(yaw) * dz) / distance),
                round(650 + 100 * strength * (math.sin(yaw) * dx + math.cos(yaw) * dz) / distance))

    def observe(self):
        pending, self.pending_observation = self.pending_observation, None
        if pending is not None:
            output, received = pending
            elapsed = time.monotonic() - received
            # Reuse only across immediately adjacent cycles. Screenshots, phase
            # transitions and waits must not keep a prior device clock fresh.
            if 0 <= elapsed <= .25:
                return route_state(output, elapsed)
        return route_state()

    def choose(self, state):
        point, evidence = self.choose_with_recovery(state)
        if self.waypoint_evidence is not None:
            evidence["building_route"] = self.waypoint_evidence
        return point, evidence

    def choose_with_recovery(self, state):
        point = self.route_point(state)
        epoch = state.get("telemetry_epoch_s")
        if epoch is None:
            return point, {"reason": "movement telemetry timestamp unavailable"}
        epoch = float(epoch)
        if not math.isfinite(epoch):
            raise RuntimeError("Invalid movement telemetry timestamp")
        if self.previous is not None and epoch < self.previous[0]:
            return point, {"reason": "no new movement observation"}
        zone_distance = math.hypot(float(state["x"]) - float(state["center_x"]),
                                   float(state["z"]) - float(state["center_z"]))
        zone_margin = float(state["radius"]) - zone_distance
        if self.clearance is not None:
            started, wx, wz, start_x, start_z = self.clearance
            distance = math.hypot(float(state["x"]) - start_x,
                                  float(state["z"]) - start_z)
            # Healing slows movement but must not reverse a just-cleared
            # corner back into cover (r807 cycle 6). Keep the same bounds.
            if (0 <= epoch - started < 3 and distance < 8
                    and zone_margin > 25):
                yaw = float(state["yaw"])
                point = (round(180 + 100 * (math.cos(yaw) * wx - math.sin(yaw) * wz)),
                         round(650 + 100 * (math.sin(yaw) * wx + math.cos(yaw) * wz)))
            else:
                self.clearance = None
        # A fresh physics contact can identify a corner before the next
        # displacement window. A blind 90-degree turn can hit its other wall.
        # Healing also permits movement: confirmed contact must still escape.
        # Older APKs omit these compact fields and retain the existing fallback.
        if ((self.previous is None or epoch > self.previous[0])
                and 0 <= state.get("planar_speed", math.inf) < .5):
            normals = []
            for normal in state.get("wall_normals_xz", []):
                if not isinstance(normal, (list, tuple)) or len(normal) != 2:
                    continue
                nx, nz = map(float, normal)
                length = math.hypot(nx, nz)
                if math.isfinite(length) and length > .5:
                    unit = (nx / length, nz / length)
                    if unit not in normals:
                        normals.append(unit)
            wx = sum(n[0] for n in normals)
            wz = sum(n[1] for n in normals)
            length = math.hypot(wx, wz)
            yaw = float(state["yaw"])
            lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
            desired_x = math.cos(yaw) * lx + math.sin(yaw) * lz
            desired_z = -math.sin(yaw) * lx + math.cos(yaw) * lz
            # Check the course that will actually be held below. The orbit
            # can point away from a new wall while an earlier escape course
            # still drives into it.
            if (self.recovery is not None and zone_margin > 25
                    and 0 <= epoch - self.recovery[0] < 10):
                desired_x, desired_z = self.recovery[1:3]
            if (length > .1
                    and any(desired_x * nx + desired_z * nz < -.1 for nx, nz in normals)
                    and all((wx * nx + wz * nz) / length > .1 for nx, nz in normals)):
                wx, wz = wx / length, wz / length
                self.recovery = (epoch, wx, wz, float(state["x"]), float(state["z"]))
                self.clearance = None
                self.contact_recovery_epoch = epoch
                self.previous = (epoch, float(state["x"]), float(state["z"]))
                lx = math.cos(yaw) * wx - math.sin(yaw) * wz
                lz = math.sin(yaw) * wx + math.cos(yaw) * wz
                return (round(180 + 100 * lx), round(650 + 100 * lz)), {
                    "reason": "fresh blocked wall contact; outward recovery",
                    "wall_normals_xz": normals}
        # Inward input cannot cross a confirmed wall. At the zone edge retain
        # that escape only for the same contact observation (including camera
        # turns); the next fresh sample must confirm blockage again. Ordinary
        # low-displacement recovery still yields immediately to zone movement.
        if zone_margin <= 25 and not (
                self.recovery is not None and self.contact_recovery_epoch == epoch):
            self.recovery = None
            self.contact_recovery_epoch = None
            self.previous = (epoch, float(state["x"]), float(state["z"]))
            return point, {"reason": "zone margin; prefer inward route",
                           "zone_margin_m": zone_margin}
        if self.recovery is not None:
            started, wx, wz, start_x, start_z = self.recovery
            elapsed = epoch - started
            displacement = math.hypot(float(state["x"]) - start_x,
                                      float(state["z"]) - start_z)
            sample_elapsed = epoch - self.previous[0]
            # r764 travelled 20m clear of a wall but kept escaping until it
            # hit the opposite row. End a successful escape on fresh, clear
            # progress instead of holding its direction for the whole timer.
            if (epoch > self.previous[0] and displacement >= 6
                    and state.get("wall_normals_xz") == []
                    and state.get("heal_left", 0) <= 0):
                # Input batches release the stick before telemetry is read.
                # r801 covered 7.6m but sampled zero instantaneous speed;
                # fresh displacement still proves that the escape progressed.
                self.recovery = None
                self.contact_recovery_epoch = None
                self.previous = (epoch, float(state["x"]), float(state["z"]))
                # r788 immediately returned into the same corner after 6m
                # of clearance. If the orbit reverses the escape, briefly
                # travel perpendicular to it, toward the orbit's preferred
                # side. Bound this by both time and distance above.
                yaw = float(state["yaw"])
                lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
                desired_x = math.cos(yaw) * lx + math.sin(yaw) * lz
                desired_z = -math.sin(yaw) * lx + math.cos(yaw) * lz
                if (desired_x * wx + desired_z * wz < -.1
                        and state.get("heal_left", 0) <= 0):
                    sx, sz = -wz, wx
                    if sx * desired_x + sz * desired_z < 0:
                        sx, sz = -sx, -sz
                    self.clearance = (epoch, sx, sz, float(state["x"]), float(state["z"]))
                    point = (round(180 + 100 * (math.cos(yaw) * sx - math.sin(yaw) * sz)),
                             round(650 + 100 * (math.sin(yaw) * sx + math.cos(yaw) * sz)))
                return point, {"reason": "clear progress; end recovery",
                               "bounded_clearance": self.clearance is not None,
                               "recovery_displacement_m": displacement,
                               "recovery_elapsed_s": elapsed}
            # A full failed attempt must not select the same blocked course.
            # Reverse only with fresh observations and room inside the zone;
            # healing or a telemetry gap is not evidence of an obstacle.
            if (10 <= elapsed <= 16 and 0 < sample_elapsed <= 8
                    and displacement < 2 and state.get("heal_left", 0) <= 0
                    and zone_distance < state["radius"] - 25):
                wx, wz = -wx, -wz
                self.contact_recovery_epoch = None
                self.recovery = (epoch, wx, wz, float(state["x"]), float(state["z"]))
                self.previous = (epoch, float(state["x"]), float(state["z"]))
                yaw = float(state["yaw"])
                lx = math.cos(yaw) * wx - math.sin(yaw) * wz
                lz = math.sin(yaw) * wx + math.cos(yaw) * wz
                return (round(180 + 100 * lx), round(650 + 100 * lz)), {
                    "reason": "failed lateral recovery; reverse course",
                    "recovery_elapsed_s": elapsed,
                    "recovery_displacement_m": displacement}
            # Keep the escape course across repeated telemetry and camera turns;
            # immediately returning to the orbit can steer into the same wall.
            if (0 <= epoch - started < 10
                    and (state.get("heal_left", 0) <= 0
                         or self.contact_recovery_epoch == started)):
                yaw = float(state["yaw"])
                lx = math.cos(yaw) * wx - math.sin(yaw) * wz
                lz = math.sin(yaw) * wx + math.cos(yaw) * wz
                self.previous = (epoch, float(state["x"]), float(state["z"]))
                return (round(180 + 100 * lx), round(650 + 100 * lz)), {
                    "reason": "bounded lateral recovery",
                    "recovery_elapsed_s": epoch - started}
            self.recovery = None
            self.contact_recovery_epoch = None
        current = (epoch, float(state["x"]), float(state["z"]))
        previous = self.previous
        if previous is not None and epoch <= previous[0]:
            return point, {"reason": "no new movement observation"}
        self.previous = current
        if previous is None:
            self.displacement_window = (current, current)
            return point, {"reason": "first movement observation"}
        elapsed = epoch - previous[0]
        distance = math.hypot(current[1] - previous[1], current[2] - previous[2])
        evidence = {"reason": "normal route", "sample_elapsed_s": elapsed,
                    "sample_displacement_m": distance}
        # Short touch batches now produce observations every 2-4 seconds.
        # Accumulate a bounded window instead of requiring each batch to last
        # four seconds. Reset after progress, healing, gaps, or other controls.
        window = self.displacement_window
        anchor = window[0] if window is not None and window[1] == previous else previous
        window_elapsed = epoch - anchor[0]
        window_distance = math.hypot(current[1] - anchor[1], current[2] - anchor[2])
        if (elapsed > 8 or window_elapsed > 8 or window_distance >= 2
                or state.get("heal_left", 0) > 0):
            self.displacement_window = (current, current)
            return point, evidence
        self.displacement_window = (anchor, current)
        evidence.update(displacement_window_s=window_elapsed,
                        displacement_window_m=window_distance)
        # Low displacement is only a recovery heuristic, not proof of collision.
        # Exclude long telemetry gaps and explicit slow healing movement.
        if window_elapsed < 4:
            return point, evidence
        lx, lz = (point[0] - 180) / 100, (point[1] - 650) / 100
        # Rotate 90 degrees; choose the side pointing toward the zone center.
        sx, sz = -lz, lx
        yaw = float(state["yaw"])
        wx = math.cos(yaw) * sx + math.sin(yaw) * sz
        wz = -math.sin(yaw) * sx + math.cos(yaw) * sz
        if wx * (state["center_x"] - state["x"]) + wz * (state["center_z"] - state["z"]) < 0:
            sx, sz = -sx, -sz
            wx, wz = -wx, -wz
        self.recovery = (epoch, wx, wz, current[1], current[2])
        self.contact_recovery_epoch = None
        evidence["reason"] = "fresh low displacement; start lateral recovery"
        return (round(180 + 100 * sx), round(650 + 100 * sz)), evidence


class SupplyControls:
    """Issue at most one supply touch per periodic gameplay sample."""

    def __init__(self):
        self.last_epoch = None
        self.heal_pending_until = 0.0
        self.heal_start_state = None
        self.heal_retry_after = 0.0
        self.last_health_sample = None

    def healing(self, state):
        # Telemetry arrives every five seconds, slower than the normal 3.5s
        # heal. Remember successful touch submission across reused samples.
        # This bounds a combat pause; it does not assert the heal succeeded.
        return (state.get("heal_left", 0) > 0
                or time.monotonic() < self.heal_pending_until)

    def heal_submitted(self):
        self.heal_pending_until = time.monotonic() + 3.5

    def observe_post_input(self, state, minimum_epoch):
        # Only a sample proven newer than the completed input can release the
        # pending guard. Damage cancels healing without consuming a medkit.
        # A pre-touch sample must never cause a second, cancelling heal touch.
        if (state["telemetry_epoch_s"] >= minimum_epoch
                and state["heal_left"] <= 0):
            self.heal_pending_until = 0.0
            if self.heal_start_state is not None:
                health, medkits = self.heal_start_state
                # r916: repeated damage-interrupted heals kept movement at
                # 2m/s in the open. Allow an escape/combat interval first.
                # A consumed medkit can indicate completion despite damage.
                if state["medkits"] == medkits and state["health"] < health:
                    self.heal_retry_after = time.monotonic() + 8.0
                self.heal_start_state = None

    def reloading(self, state):
        # Reobserve while reload blocks healing, without touching reload again.
        # The device reports whole-second sample age, a conservative bound.
        return state.get("reload_left", 0) > max(
            0.0, float(state.get("telemetry_age_s", 0)))

    def choose(self, state):
        fields = ("health", "medkits", "heal_left", "reload_left", "ammo",
                  "reserve", "telemetry_epoch_s")
        if any(key not in state for key in fields):
            return "none", "supply telemetry unavailable"
        if any(not math.isfinite(float(state[key])) for key in fields):
            raise RuntimeError("Invalid supply telemetry")
        age = float(state.get("telemetry_age_s", 0))
        if not math.isfinite(age):
            raise RuntimeError("Invalid supply telemetry age")
        frag_warning = state.get("frag_warning", False)
        if not isinstance(frag_warning, bool):
            raise RuntimeError("Invalid grenade warning telemetry")
        # r1066 had a roughly six-second damage-free window, but the eight-
        # second first-heal guard blocked both available medkits. Allow a
        # first attempt after 3.5 seconds without newly observed damage.
        # Interrupted heals retain their longer eight-second escape guard.
        # Only newer samples advance this guard.
        previous = self.last_health_sample
        if previous is None or state["telemetry_epoch_s"] > previous[0]:
            if (previous is not None and state["health"] < previous[1]
                    and state["medkits"] == previous[2]):
                self.heal_retry_after = max(
                    self.heal_retry_after, time.monotonic() + 3.5)
            self.last_health_sample = (
                state["telemetry_epoch_s"], state["health"], state["medkits"])
        # Device time is whole seconds: age is a conservative elapsed bound.
        # Reused five-second samples must not retain an expired reload timer.
        reload_active = self.reloading(state)
        if state["telemetry_epoch_s"] == self.last_epoch:
            return "none", "sample already used for supply input"
        # A newly observed sample can still precede the submitted touch.
        # A second heal touch toggles healing off; reload can interrupt it.
        if time.monotonic() < self.heal_pending_until:
            return "none", "submitted heal awaiting completion"
        if state["heal_left"] > 0 or reload_active:
            return "none", "healing or reloading in progress"
        action, reason = "none", "supplies not needed"
        # Samples are five seconds apart and normal healing takes 3.5 seconds.
        # Begin before another movement/fire cycle consumes that margin.
        # r1068 stayed at 81.6 health for ~40s, then died under renewed fire
        # with both medkits unused. Use that quiet window before the next hit.
        if (state["health"] <= 85 and state["medkits"] > 0
                and time.monotonic() >= self.heal_retry_after
                and not frag_warning):
            action, reason = "heal", "health low and medkit available"
            self.heal_start_state = (state["health"], state["medkits"])
        elif state["ammo"] <= 8 and state["reserve"] > 0:
            action, reason = "reload", "magazine low and reserve available"
        elif frag_warning:
            reason = "visible frag warning: continue movement instead of starting heal"
        elif time.monotonic() < self.heal_retry_after:
            reason = "recent damage: continue movement and combat before healing"
        if action != "none":
            self.last_epoch = state["telemetry_epoch_s"]
        return action, reason


def combat_cycle(size, cycle, supplies=None, route=None):
    width, height = size
    state = route.observe() if route is not None else route_state()
    controls = route or RouteControls()
    supplies = supplies or SupplyControls()
    action, reason = supplies.choose(state)
    healing = action == "heal" or supplies.healing(state)
    multitouch = os.environ.get("ANDROID_MULTITOUCH") == "1"
    reloading = supplies.reloading(state)
    evading = (multitouch and controls.building_route
               and state.get("frag_warning") is True)
    controls.movement_supply_options = (
        dict(healing=healing, reload=action == "reload",
             heal=action == "heal", reloading=reloading)
        if multitouch else None)
    if evading:
        controls.movement_supply_options["evading"] = True
    (x, y), movement = controls.choose(state)
    recovery = route is not None and route.recovery is not None
    touch_options = {"recovery": True} if recovery else {}
    if evading:
        touch_options["evading"] = True
    if controls.waypoint_evidence and "distance_m" in controls.waypoint_evidence:
        touch_options["route_feedback"] = True
        touch_options["route_distance_m"] = controls.waypoint_evidence["distance_m"]
    if reloading:
        touch_options["reloading"] = True
    hold_ms = 2000
    if multitouch:
        from android_multitouch import combat_events
        hold_ms = combat_events(size, (x, y), cycle, healing, action == "reload",
                                heal=action == "heal", **touch_options)[-1][0]
    with (OUT / "route-decisions.jsonl").open("a") as stream:
        stream.write(json.dumps({"cycle": cycle, "state": state,
                                 "joystick": [x, y], "hold_ms": hold_ms,
                                 "input_mode": "multitouch" if multitouch else "sequential",
                                 "supply_action": action, "supply_reason": reason,
                                 "combat_deferred_for_healing": healing,
                                 "combat_deferred_for_reloading": multitouch and reloading,
                                 "combat_deferred_for_grenade": evading,
                                 "movement_decision": movement,
                                 "host_monotonic_s": time.monotonic()}) + "\n")
    # HEAL toggles cancellation: issue once, before movement, from a fresh
    # sample. Damage can still cancel it under the normal gameplay rules.
    if action == "heal" and not multitouch:
        tap(1010, 775, size)
        supplies.heal_submitted()
    if multitouch:
        # The test package must install the shell dex jar before enabling this.
        # Import lazily to preserve existing recoverable test packages.
        from android_multitouch import run_combat
        if action == "heal":
            supplies.heal_submitted()
        if route is None:
            run_combat(size, (x, y), cycle, OUT, healing, action == "reload",
                       heal=action == "heal", **touch_options)
        else:
            output = run_combat(size, (x, y), cycle, OUT, healing,
                                action == "reload",
                                observation_command=ROUTE_OBSERVATION_COMMAND,
                                heal=action == "heal", **touch_options)
            received = time.monotonic()
            feedback_wait = None
            # Check even the last cycle, before a caller stops collecting.
            try:
                after = route_state(output)
                if touch_options.get("route_feedback"):
                    output, after, feedback_wait = post_look_observation(output)
                    received = time.monotonic()
            except RuntimeError as error:
                # Preserve the final failed cycle as well as successful ones.
                # Do not accept dead/stale samples as valid route observations.
                with (OUT / "combat-observations.jsonl").open("a") as stream:
                    stream.write(json.dumps({
                        "cycle": cycle, "supply_action": action,
                        "before": state, "after": None,
                        "observation_error": str(error),
                        "raw_observation": getattr(error, "raw_observation", output),
                        "host_received_monotonic_s": received,
                    }) + "\n")
                raise
            # Android injection receipts do not acknowledge game actions.
            # Keep the game's next sample linked to the triggering cycle;
            # damage can cancel healing or offset health gained on completion.
            if feedback_wait is not None:
                supplies.observe_post_input(
                    after, feedback_wait["minimum_telemetry_epoch_s"])
            with (OUT / "combat-observations.jsonl").open("a") as stream:
                stream.write(json.dumps({
                    "cycle": cycle, "supply_action": action,
                    "before": state, "after": after,
                    "host_received_monotonic_s": received,
                    "post_look_feedback_wait": feedback_wait,
                }) + "\n")
            route.pending_observation = (output, received)
        return
    tap(x, y, size, hold_ms=2000)
    # AIM is a toggle. Pair touches so the scan uses the same sensitivity.
    # Firing is unavailable during healing. Avoid stopping for three
    # ineffective touches while exposed to bots; retain movement and looking.
    if not healing:
        tap(1150, 635, size)
        tap(1330, 660, size, hold_ms=500)
        tap(1150, 635, size)
    # The controls are mutually exclusive while either action is active.
    # Never send HEAL again from the same stale sample: it toggles cancellation.
    if action == "reload":
        tap(1170, 775, size)
    start, end = combat_look_points(size)
    adb("shell", "input", "swipe", *map(str, (*start, *end)), "300")


def capture_combat_failure(evidence, prefix):
    """Collect only after presentation collection stops; retain original error."""
    evidence["failure_capture_scope"] = "After collector stop; not live combat evidence"
    for suffix, command in (
        ("png", ["exec-out", "screencap", "-p"]),
        ("logcat", ["logcat", "-d", "-v", "epoch", "-t", "2000", "godot:I", "*:S"]),
    ):
        try:
            completed = subprocess.run(
                ["adb", *command], capture_output=True, check=True, timeout=10)
            if suffix == "png" and not completed.stdout.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError("Failure screenshot is not PNG")
            path = OUT / f"{prefix}.{suffix}"
            path.write_bytes(completed.stdout)
            evidence[f"failure_{suffix}_path"] = path.name
        except Exception as exc:
            evidence[f"failure_{suffix}_error"] = str(exc)


def export_diagnostic_frame_times(output, evidence):
    """Export retained presentation intervals without masking a gameplay error."""
    try:
        timestamps_path = output / "intervals" / "timestamps.json"
        if timestamps_path.exists():
            timestamps = json.loads(timestamps_path.read_text())
            intervals = [(b - a) / 1e6 for a, b in zip(timestamps, timestamps[1:])]
            (output / "diagnostic-frame-times.json").write_text(json.dumps(
                {"frame_times_ms": intervals}))
    except Exception as exc:
        evidence["frame_export_error"] = str(exc)


@contextmanager
def warmup_present_diagnostic(seconds):
    """Retain early-route evidence even on death; never acceptance data."""
    if seconds <= 0:
        yield
        return
    stop = Event()
    output = OUT / "warmup-present-probe"
    evidence = {"acceptance": False, "scope": "Warmup only; may include death transition",
                "host_start_monotonic_ns": time.monotonic_ns(),
                "input_evidence": "input-commands.jsonl",
                "route_evidence": "route-decisions.jsonl"}
    with ThreadPoolExecutor(max_workers=1) as collector:
        pending = collector.submit(probe, PACKAGE, output, seconds, None, stop)
        try:
            yield
        except BaseException as exc:
            evidence["gameplay_error"] = str(exc)
            raise
        finally:
            evidence["host_stop_requested_monotonic_ns"] = time.monotonic_ns()
            stop.set()
            # probe retains errors and raw timestamps. Diagnostic failure must
            # not replace the original gameplay failure or stop normal sampling.
            try:
                evidence["present_probe"] = pending.result()
            except Exception as exc:
                evidence["collector_error"] = str(exc)
            export_diagnostic_frame_times(output, evidence)
            if "gameplay_error" in evidence:
                capture_combat_failure(evidence, "warmup-failure")
            evidence["host_cleanup_finished_monotonic_ns"] = time.monotonic_ns()
            (OUT / "warmup-presentation-diagnostic.json").write_text(
                json.dumps(evidence, indent=2))


def wait_for_combat_seed(pending, ready, timeout=60, on_wait=None):
    """Keep gameplay active during discovery; only seeded presents are measured."""
    deadline = time.monotonic() + timeout
    while not ready.wait(.1):
        if pending.done():
            raise RuntimeError(f"Combat probe could not seed: {pending.result()}")
        if time.monotonic() >= deadline:
            raise TimeoutError("Combat probe did not seed before input deadline")
        if on_wait is not None:
            on_wait()


def combat_background_work(operation, on_wait):
    """Keep the sole input controller active while boundary I/O completes."""
    pending = Future()
    def worker():
        try:
            pending.set_result(operation())
        except BaseException as exc:
            pending.set_exception(exc)
    thread = Thread(target=worker, name="combat-boundary-io")
    thread.start()
    try:
        while True:
            try:
                return pending.result(timeout=.05)
            except FutureTimeout:
                # An operation's own TimeoutError must still fail the test.
                if pending.done():
                    return pending.result()
            on_wait()
    finally:
        # Never leave a snapshot writer running after a gameplay failure.
        thread.join()


def measure_combat(size, seconds, warmup_seconds, supplies=None, route=None):
    # Start before warmup so an early death cannot discard the only stall trace.
    # Keep a single capture across both phases: stopping/downloading at the
    # boundary would leave the player idle before the measured route.
    # The bounded ring can overwrite early events; verify coverage separately.
    with system_trace(OUT):
        return _measure_combat(size, seconds, warmup_seconds, supplies, route)


def _measure_combat(size, seconds, warmup_seconds, supplies=None, route=None):
    cycle = 0
    supplies = supplies or SupplyControls()
    route = route or RouteControls()
    boundary_cycles = 0
    def boundary_gameplay():
        nonlocal cycle, boundary_cycles
        combat_cycle(size, cycle, supplies, route)
        cycle += 1
        boundary_cycles += 1
    warmup_start = time.monotonic()
    with warmup_present_diagnostic(warmup_seconds):
        while time.monotonic() - warmup_start < warmup_seconds:
            combat_cycle(size, cycle, supplies, route)
            cycle += 1
    warmup_elapsed = time.monotonic() - warmup_start
    # Snapshot warmup diagnostics without clearing the live route telemetry.
    # Gameplay emits every five seconds; clearing here can stop input before
    # the next sample arrives. The presentation probe seeds its own ring and
    # excludes warmup independently of logcat.
    log_marker = "FPS_MEASUREMENT_START_" + str(time.monotonic_ns())
    def snapshot_and_mark():
        (OUT / "warmup.logcat").write_bytes(adb("logcat", "-d"))
        adb("shell", "log", "-t", "FPSProbe", log_marker)
    boundary_start_ns = time.monotonic_ns()
    try:
        combat_background_work(snapshot_and_mark, boundary_gameplay)
    finally:
        (OUT / "combat-boundary.json").write_text(json.dumps({
            "host_start_monotonic_ns": boundary_start_ns,
            "host_end_monotonic_ns": time.monotonic_ns(),
            "completed_cycles": boundary_cycles,
            "acceptance": False,
        }))
    stop = Event()
    ready = Event()
    with cpu_sample(OUT, PACKAGE), ThreadPoolExecutor(max_workers=1) as collector:
        pending = collector.submit(probe, PACKAGE, OUT / "present-probe", seconds,
                                   ready=ready, stop=stop)
        measured_cycles = 0
        seed_startup_cycles = 0
        def seed_gameplay():
            nonlocal cycle, seed_startup_cycles
            combat_cycle(size, cycle, supplies, route)
            cycle += 1
            seed_startup_cycles += 1
        # Layer discovery and ring seeding take variable time. Keep touching
        # until collection finishes, not merely for a fixed number of cycles.
        try:
            wait_for_combat_seed(pending, ready, on_wait=seed_gameplay)
            while not pending.done():
                combat_cycle(size, cycle, supplies, route)
                cycle += 1
                measured_cycles += 1
        except BaseException as exc:
            # Death/failing input invalidates the whole combat window. Stop
            # promptly, retain raw polls, and preserve the gameplay exception.
            evidence = {"acceptance": False, "gameplay_error": str(exc),
                        "scope": "Aborted combat; may include death transition",
                        "host_stop_requested_monotonic_ns": time.monotonic_ns(),
                        "completed_cycles": measured_cycles,
                        "seed_startup_cycles": seed_startup_cycles}
            stop.set()
            try:
                evidence["present_probe"] = pending.result()
            except Exception as collector_error:
                evidence["collector_error"] = str(collector_error)
            export_diagnostic_frame_times(OUT / "present-probe", evidence)
            capture_combat_failure(evidence, "combat-failure")
            (OUT / "aborted-combat-diagnostic.json").write_text(json.dumps(evidence))
            raise
        report = pending.result()
        # End gameplay telemetry before trace compression/download leaves the
        # character idle. Keep that cleanup in raw logs, outside this window.
        log_end_marker = "FPS_MEASUREMENT_END_" + str(time.monotonic_ns())
        adb("shell", "log", "-t", "FPSProbe", log_end_marker)
        measurement_end = time.monotonic()
    return {"requested_seconds": seconds, "warmup_requested_seconds": warmup_seconds,
            "log_marker": log_marker,
            "log_end_marker": log_end_marker,
            "warmup_host_start_monotonic_s": warmup_start,
            "measurement_host_end_monotonic_s": measurement_end,
            "warmup_elapsed_seconds": warmup_elapsed, "measured_cycles": measured_cycles,
            "boundary_cycles": boundary_cycles,
            "seed_startup_cycles": seed_startup_cycles,
            "present_probe": report}


def measurement_logs(logs, marker, end_marker=None):
    lines = logs.splitlines(keepends=True)
    def marker_index(value):
        # adbd also logs the shell command; only the emitted tag is a boundary.
        return next((i for i, line in enumerate(lines)
                     if re.search(r"\bFPSProbe\s*:\s*" + re.escape(value) +
                                  r"\s*$", line)), None)
    start = marker_index(marker)
    if start is None:
        raise RuntimeError("Measurement log marker missing; cannot exclude warmup")
    end = marker_index(end_marker) if end_marker else len(lines)
    if end is None or end <= start:
        raise RuntimeError("Measurement end marker missing or out of order")
    return "".join(lines[start + 1:end])


def initial_route(size, screenshots=True):
    with phase("initial-solo"):
        tap(330, 260, size)
        time.sleep(1)
        tap(140, 490, size)
        tap(180, 550, size, hold_ms=3000)
    if screenshots:
        capture("02-solo")
    with phase("initial-fire"):
        tap(1330, 660, size, hold_ms=500)
    if screenshots:
        capture("03-fire")
    width, height = size
    with phase("initial-look"):
        adb("shell", "input", "swipe", str(int(width * .65)), str(int(height * .45)),
            str(int(width * .68)), str(int(height * .45)), "300")
    if screenshots:
        capture("04-look")


def measure_initial_route(size, supplies=None, route=None):
    """Unwarmed transition diagnostic; never counted as steady acceptance."""
    ready = Event()
    with ThreadPoolExecutor(max_workers=1) as collector:
        pending = collector.submit(probe, PACKAGE, OUT / "initial-present-probe", 25, ready)
        deadline = time.monotonic() + 60
        while not ready.wait(.1):
            if pending.done():
                raise RuntimeError(f"Initial probe could not seed: {pending.result()}")
            if time.monotonic() >= deadline:
                raise TimeoutError("Initial probe did not seed within 60 seconds")
        with phase("initial-route-no-screenshots"):
            initial_route(size, screenshots=False)
            cycle = 0
            supplies = supplies or SupplyControls()
            route = route or RouteControls()
            while not pending.done():
                combat_cycle(size, cycle, supplies, route)
                cycle += 1
        report = pending.result()
    (OUT / "initial-route-diagnostic.json").write_text(json.dumps({
        "scope": "Unwarmed initial solo/fire/look; screenshots disabled after menu",
        "acceptance": False, "present_probe": report,
        "phase_evidence": "phase-commands.jsonl",
        "input_evidence": "input-commands.jsonl"}, indent=2))
    if not report.get("valid"):
        raise RuntimeError(f"Initial presentation diagnostic failed: {report}")
    capture("05-after-initial-probe")


def diagnose_combat_views(size, supplies, route):
    """Separate, opt-in visual diagnosis; screencap perturbs frame presentation."""
    report = {"acceptance": False,
              "scope": "Live combat screenshots; no performance measurement",
              "route_evidence": "route-decisions.jsonl",
              "input_evidence": "input-commands.jsonl", "views": []}
    try:
        for cycle in range(8):
            combat_cycle(size, cycle, supplies, route)
            if cycle % 2:
                continue
            view = {"cycle": cycle, "host_start_monotonic_ns": time.monotonic_ns()}
            report["views"].append(view)
            completed = subprocess.run(
                ["adb", "exec-out", "screencap", "-p"],
                capture_output=True, check=True, timeout=10)
            if not completed.stdout.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError("Combat screenshot is not PNG")
            path = OUT / f"live-combat-{cycle:02d}.png"
            path.write_bytes(completed.stdout)
            view.update(path=path.name, host_end_monotonic_ns=time.monotonic_ns())
    except BaseException as exc:
        report["gameplay_error"] = str(exc)
        raise
    finally:
        (OUT / "live-combat-diagnostic.json").write_text(json.dumps(report, indent=2))


def main():
    ground_materials = os.environ.get("ANDROID_GROUND_MATERIAL_DIAGNOSTIC") == "1"
    if ground_materials and not PROFILE_GAME:
        raise ValueError("Ground material diagnostic requires gameplay profiling")
    seconds = int(os.environ.get("ANDROID_PRESENT_SECONDS", "25"))
    warmup_seconds = int(os.environ.get("ANDROID_ACTIVE_WARMUP_SECONDS", "30"))
    if not 10 <= seconds <= 600 or not 0 <= warmup_seconds <= 600:
        raise ValueError("Presentation duration must be 10..600s and active warmup 0..600s")
    adb("shell", "am", "force-stop", PACKAGE)
    adb("logcat", "-c")
    if PROFILE_GAME:
        adb("shell", "am", "start", "-W", "-n",
            PACKAGE + "/com.godot.game.GodotApp",
            "--esa", "command_line_params",
            ("--remote-debug,tcp://127.0.0.1:6007," if
             os.environ.get("ANDROID_VISUAL_PROFILE_GAMEPLAY") == "1" else "") +
            "--,--profile-game" +
            (",--profile-ground-materials" if ground_materials else ""))
    else:
        adb("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1")
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        if b"ANDROID_STARTUP: interface ready" in adb("logcat", "-d"):
            break
        time.sleep(3)
    else:
        raise RuntimeError("Native interface did not initialize")
    if ground_materials:
        marker = "ANDROID_GROUND_MATERIAL_DIAGNOSTIC "
        logs = adb("logcat", "-d").decode(errors="replace")
        reports = [json.loads(line.split(marker, 1)[1])
                   for line in logs.splitlines() if marker in line]
        if not reports or reports[-1].get("replaced", 0) <= 0:
            raise RuntimeError("APK did not apply ground material diagnostic")
        (OUT / "ground-material-diagnostic.json").write_text(
            json.dumps(reports[-1], indent=2) + "\n")
    # Scene initialization precedes the first rendered menu on slower GPUs.
    # Give shader compilation time to finish before injecting touches.
    time.sleep(100)
    if os.environ.get("ANDROID_DISMISS_DEBUG_COMPAT_WARNING") == "1":
        dismiss_debug_compatibility_warning()
    size = capture("01-menu")
    print("SCREEN_SIZE", size, flush=True)
    # This is one continuous match: preserve obstacle observations and pending
    # healing across diagnostic phases, which do not reset the player's state.
    supplies = SupplyControls()
    route = RouteControls()
    if os.environ.get("ANDROID_INITIAL_ROUTE_PROBE") == "1":
        measure_initial_route(size, supplies, route)
    else:
        # Building-route diagnostics need to reach continuous input promptly:
        # three synchronous screencaps left the player exposed before capture.
        # Keep the same movement/fire/look inputs and the normal visual review.
        initial_route(size, screenshots=not route.building_route)
    if os.environ.get("ANDROID_COMBAT_VIEW_DIAGNOSTIC") == "1":
        with phase("live-combat-visual-diagnostic"):
            diagnose_combat_views(size, supplies, route)
        print("COMBAT_VIEW_DIAGNOSTIC_ONLY: no performance acceptance", flush=True)
        return
    logs = adb("logcat", "-d").decode(errors="replace")
    # Isolate gameplay from loading/menu stalls. The first rolling telemetry
    # interval can still contain the last screenshot, so discard that interval
    # below. Do not take screenshots during measurement: adb screencap can
    # perturb rendering on the device under test.
    with phase("active-warmup-and-presentation"):
        measurement = measure_combat(size, seconds, warmup_seconds, supplies, route)
    perf_logs = adb("logcat", "-d").decode(errors="replace")
    bounded_logs = measurement_logs(perf_logs, measurement["log_marker"],
                                    measurement["log_end_marker"])
    first_sample = re.search(r"ANDROID_GAMEPLAY phase=\w+ alive=\w+[^\n]*\n", bounded_logs)
    measured_logs = bounded_logs[first_sample.end():] if first_sample else ""
    samples = [{"fps": float(fps), "p95_ms": float(p95)}
               for fps, p95 in re.findall(r"ANDROID_PERF fps=([\d.]+) p95_ms=([\d.]+)", measured_logs)]
    states = re.findall(r"ANDROID_GAMEPLAY phase=(\w+) alive=(\w+)", measured_logs)
    sections = [
        {"name": name, "mean_ms": float(mean), "peak_ms": float(peak), "count": int(count)}
        for name, mean, peak, count in re.findall(
            r"ANDROID_SECTION name=(\w+) mean_ms=([\d.]+) peak_ms=([\d.]+) count=(\d+)",
            measured_logs)
    ]
    (OUT / "gameplay-performance.json").write_text(json.dumps(
        {"scope": "native solo movement/fire/look until presentation collection ends; no screenshots during warmup or measurement; first rolling interval excluded", "samples": samples,
         "measurement": measurement,
         "profiling_requested": PROFILE_GAME, "sections": sections,
         "gameplay_states": [{"phase": phase, "alive": alive == "true"}
                             for phase, alive in states]}, indent=2))
    # Preserve snapshots even if the device log ring rolls over.
    logs += "\n" + (OUT / "warmup.logcat").read_text(errors="replace") + "\n" + perf_logs
    (OUT / "native-walkthrough.logcat").write_text(logs)
    assert not PROFILE_GAME or sections, "Profiling requested but no section telemetry received"
    assert not re.search(r"FATAL EXCEPTION|Fatal signal|SCRIPT ERROR|ANR in " + PACKAGE, logs)
    assert adb("shell", "pidof", PACKAGE).strip(), "Application exited"
    assert len(samples) >= 4, "Insufficient steady gameplay performance samples"
    assert len(states) >= 4 and all(phase == "live" and alive == "true"
                                  for phase, alive in states), "Player must remain alive in combat"
    assert min(s["fps"] for s in samples) >= 24, "Gameplay below 24 FPS"
    assert max(s["p95_ms"] for s in samples) <= 75, "Gameplay frame-time spikes exceed budget"
    # Collection and bounded telemetry are already persisted. Record a combat
    # view for review without introducing screencap stalls into measurement.
    with phase("post-measurement-visual"):
        capture("05-combat-after-measurement")
    print("NATIVE_WALKTHROUGH_CAPTURED: visual gameplay review required", flush=True)


if __name__ == "__main__":
    main()
