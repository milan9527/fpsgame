"""Build a coherent ordinary-touch combat stream; no engine input simulation."""
import json
import math
import re
from pathlib import Path
import shlex
import subprocess
import time


def clock_anchors(stderr):
    """Bound epoch-minus-monotonic offset, including wall-clock quantization.

    Use anchors locally in time; wall-clock adjustments invalidate a global
    offset. Missing anchors from older injectors are not synthesized.
    """
    anchors = []
    for line in stderr.splitlines():
        if not line.startswith("ANDROID_TOUCH_CLOCK "):
            continue
        anchor = json.loads(line.removeprefix("ANDROID_TOUCH_CLOCK "))
        before, epoch, after = (
            anchor[key] for key in
            ("monotonic_before_ns", "epoch_ms", "monotonic_after_ns"))
        if (any(type(value) is not int for value in (before, epoch, after))
                or before < 0 or after < before or epoch < 0):
            raise ValueError("Invalid device clock anchor")
        anchor["epoch_minus_monotonic_min_ns"] = epoch * 1_000_000 - after
        anchor["epoch_minus_monotonic_max_ns"] = (epoch + 1) * 1_000_000 - before
        boot_keys = ("boot_monotonic_before_ns", "boottime_ns",
                     "boot_monotonic_after_ns")
        if any(key in anchor for key in boot_keys):
            if not all(key in anchor for key in boot_keys):
                raise ValueError("Incomplete device boot clock anchor")
            boot_before, boot, boot_after = (anchor[key] for key in boot_keys)
            if (any(type(value) is not int
                    for value in (boot_before, boot, boot_after))
                    or boot_before < after or boot_after < boot_before
                    or boot < boot_before):
                raise ValueError("Invalid device boot clock anchor")
            # Only valid locally: suspend can change boot-minus-monotonic.
            # Do not substitute wall time or reconstruct absent old anchors.
            anchor["boot_minus_monotonic_min_ns"] = boot - boot_after
            anchor["boot_minus_monotonic_max_ns"] = boot - boot_before
        anchors.append(anchor)
    return anchors


def combat_look_points(size):
    """Sweep consistently through the button-free upper right viewport."""
    width, height = size
    scale = min(width / 1440, height / 900)
    return tuple(
        (round((width - 1440 * scale) / 2 + x * scale),
         round((height - 900 * scale) / 2 + 360 * scale))
        for x in (900, 1140))


def input_completion_observation(observation, anchors):
    """Use the synchronous injection boundary; retain shell-clock fallback.

    The upper millisecond bound avoids accepting telemetry from before the
    final UP. Raw stdout and anchors remain in the command evidence record.
    """
    starts = [a for a in anchors if a.get("stage") == "start"]
    ends = [a for a in anchors if a.get("stage") == "injection_end"]
    clocks = re.findall(r"^ANDROID_LOOK_END_CLOCK=(\d+\.\d{9})$",
                        observation, re.MULTILINE)
    if len(starts) != 1 or len(ends) != 1 or len(clocks) != 1:
        return observation
    start, end = starts[0], ends[0]
    elapsed_ms = (end["monotonic_before_ns"] -
                  start["monotonic_after_ns"]) / 1_000_000
    wall_elapsed_ms = end["epoch_ms"] - start["epoch_ms"]
    boundary_ms = end["epoch_ms"] + 1
    seconds, fraction = clocks[0].split(".")
    shell_ns = int(seconds) * 1_000_000_000 + int(fraction)
    if (elapsed_ms < 0 or abs(wall_elapsed_ms - elapsed_ms) > 50
            or not 0 <= shell_ns - boundary_ms * 1_000_000 <= 1_000_000_000):
        return observation
    boundary = f"{boundary_ms // 1000}.{boundary_ms % 1000:03d}000000"
    return observation.replace("ANDROID_LOOK_END_CLOCK=" + clocks[0],
                               "ANDROID_LOOK_END_CLOCK=" + boundary, 1)


def route_combat_lead_ms(distance):
    """Movement lead before 724ms of combat holds, with a 6m corner reserve."""
    if isinstance(distance, (int, float)) and math.isfinite(distance):
        return max(250, min(750, math.floor((distance - 6) * 100) - 724))
    return 250


def combat_events(size, joystick, cycle, healing=False, reload=False, heal=False,
                  recovery=False, reloading=False, route_feedback=False,
                  route_distance_m=None, evading=False):
    width, height = size
    scale = min(width / 1440, height / 900)

    def screen(x, y):
        return (round((width - 1440 * scale) / 2 + x * scale),
                round((height - 900 * scale) / 2 + y * scale))

    stick = screen(*joystick)
    events = [(0, 0, [stick])]
    # r1138 spent two exposed cycles approaching the last 2.81m/1.33m
    # of a corner while aiming. Clear this short leg before resuming combat.
    # Use the same duration in RouteControls' travel budget; retain fresh yaw
    # and ordinary supply actions, with no change to gameplay or scene content.
    clearing_corner = (
        route_feedback and not recovery
        and not (healing or reloading or heal or reload)
        and isinstance(route_distance_m, (int, float))
        and math.isfinite(route_distance_m)
        and 0 < route_distance_m <= 3)
    # Keep movement during combat and supply touches. Building-route feedback
    # releases the stick before looking: its vector uses the last observed yaw.
    # Sample route feedback sooner after escaping a contact. A full two-second
    # lead-in plus combat crossed the r775 corridor before the next observation.
    # Keep combat holds unchanged; observe movement more often while healing.
    # r856 repeatedly overshot building waypoints during the long lead-in.
    # Keep all combat holds, but observe this opt-in route more frequently.
    clock = 250 if recovery or route_feedback else (750 if healing or reloading else 2000)
    # During an existing supply action, tiny movement pulses leave the player
    # stationary through most of the observation round trip. Restore the normal
    # supply hold within the same 10m/s travel budget and 6m corner reserve as
    # combat. r956's 12m cutoff shortened a healing pulse to 250ms at 11.38m,
    # followed by a stationary observation wait. Avoid that abrupt cutoff.
    # Contact recovery and invalid distances retain the short interval.
    if (route_feedback and not recovery and (healing or reloading)
            and isinstance(route_distance_m, (int, float))
            and math.isfinite(route_distance_m)):
        clock = max(250, min(750, math.floor((route_distance_m - 6) * 100)))
    # Budget travel before the next corner instead of switching abruptly at
    # 20m. Allow 10m/s (r906 observed about 8.5m/s), reserve the 6m waypoint
    # radius, and include all 724ms of aim/fire/release holds. The speed is a
    # conservative diagnostic estimate, not a collision or survival guarantee.
    # Keep the existing 250..750ms limits and fresh-yaw observation barrier.
    if (route_feedback and not recovery
            and not (healing or reloading or heal or reload)
            and isinstance(route_distance_m, (int, float))
            and math.isfinite(route_distance_m)):
        clock = route_combat_lead_ms(route_distance_m)
    # A visible grenade warning calls for movement without the aim/fire speed
    # penalty. RouteControls derives stick strength from this exact duration.
    # Keep a bounded pulse and obtain fresh yaw before the next route decision.
    if (evading or clearing_corner) and route_feedback and not recovery:
        clock = 250
        if isinstance(route_distance_m, (int, float)) and math.isfinite(route_distance_m):
            clock = max(250, min(750, math.floor(route_distance_m * 100)))

    def secondary(point, duration, end=None):
        nonlocal clock
        events.append((clock, 5 | (1 << 8), [stick, point]))
        # Stationary holds need only DOWN/UP: Android retains both pointers.
        # Avoid synchronous WAIT_FOR_FINISH injections of unchanged positions;
        # keep the actual look trajectory and all button hold times intact.
        for elapsed in (range(16, duration, 16) if end is not None else ()):
            ratio = elapsed / duration
            target = tuple(
                round(a + (b - a) * ratio) for a, b in zip(point, end))
            events.append((clock + elapsed, 2, [stick, target]))
        events.append((clock + duration, 6 | (1 << 8), [stick, end or point]))
        clock += duration + 32

    if heal:
        # Start healing while moving, then return for fresh route feedback.
        # SupplyControls retains the pending heal across these shorter cycles
        # so stale telemetry cannot trigger another cancelling heal touch.
        clock = 16
        secondary(screen(1010, 775), 64)
        clock += 750
    elif reload:
        # r795 requested a reload but spent 2.7 seconds moving/firing first.
        # Submit it immediately and obtain route feedback during the reload;
        # SupplyControls uses fresh reload_left telemetry before retrying.
        clock = 16
        secondary(screen(1170, 775), 64)
        clock += 750
    if not (healing or heal or reload or reloading or evading or clearing_corner):
        secondary(screen(1150, 635), 64)
        secondary(screen(1330, 660), 500)
        secondary(screen(1150, 635), 64)
    # Alternating 2%-width drags cancelled each other in r822 and left
    # threats outside the view. Use ordinary touch to scan successive sectors.
    start, end = combat_look_points(size)
    if route_feedback:
        # r867 drifted into the building while the look changed yaw under a
        # held camera-relative stick. Resume movement after observing fresh yaw.
        events.append((clock, 1, [stick]))
        clock += 32
        events.append((clock, 0, [start]))
        # Keep the full scan distance but spend less time standing exposed.
        # Fresh yaw feedback is still required before resuming the stick.
        look_duration = 150
        for elapsed in range(16, look_duration, 16):
            target = tuple(round(a + (b - a) * elapsed / look_duration)
                           for a, b in zip(start, end))
            events.append((clock + elapsed, 2, [target]))
        events.append((clock + look_duration, 1, [end]))
        return events
    secondary(start, 300, end)
    events.append((clock, 1, [stick]))
    return events


def encode(events):
    return "".join(" ".join(map(str, [offset, action, len(points),
                                    *(value for point in points for value in point)])) + "\n"
                   for offset, action, points in events)


def device_stage_command(stage):
    # Shell builtins avoid launching another diagnostic process. /proc/uptime
    # includes suspend time: compare these stamps with each other, not Java's
    # uptimeMillis receipts. They are transport diagnostics, not frame times.
    if stage not in ("inject_start", "inject_end", "observation_end"):
        raise ValueError("Unknown touch transport stage")
    return ("{ read -r touch_uptime touch_idle < /proc/uptime && "
            "printf 'ANDROID_TOUCH_STAGE " + stage
            + " boottime_s=%s\\n' \"$touch_uptime\" >&2; }")


def injection_command(payload):
    # One transport round trip, but still read from a device file: Device Farm
    # does not reliably forward host stdin to app_process. Quote literal data,
    # use a fixed printf format, and never inject after a failed file write.
    return ("printf %s " + shlex.quote(payload)
            + " > /data/local/tmp/iron-touch-events.txt && "
            + device_stage_command("inject_start") + " && "
            "CLASSPATH=/data/local/tmp/iron-multitouch.jar "
            "app_process /system/bin MultiTouch"
            " < /data/local/tmp/iron-touch-events.txt && "
            + device_stage_command("inject_end"))


def run_combat(size, joystick, cycle, output_dir, healing=False, reload=False,
               observation_command=None, heal=False, recovery=False, reloading=False,
               route_feedback=False, route_distance_m=None, evading=False):
    """Requires MultiTouch dex jar at /data/local/tmp/iron-multitouch.jar.

    Receipts report shell injection acceptance, not gameplay or frame evidence.
    Fail closed; never fall back to sequential single-pointer commands.
    """
    events = combat_events(size, joystick, cycle, healing, reload, heal, recovery,
                           reloading, route_feedback, route_distance_m, evading)
    record = {"cycle": cycle, "events": events, "success": False,
              "host_start_monotonic_s": time.monotonic()}
    try:
        # Keep the exact stream as evidence and avoid app_process depending on
        # stdin forwarding through the Device Farm adb shell transport.
        event_file = Path(output_dir) / f"multitouch-cycle-{cycle}.txt"
        event_file.write_text(encode(events))
        record["transport"] = "single-shell-file"
        command = injection_command(encode(events))
        marker = "\nANDROID_TOUCH_OBSERVATION\n"
        if observation_command is not None:
            # Timestamp before logcat collection: a sample produced during that
            # collection can already be fresh enough for the next route decision.
            command += " && printf %s " + shlex.quote(marker + "ANDROID_LOOK_END_CLOCK=")
            command += " && date +%s.%N && { " + observation_command + "; }"
            command += " && " + device_stage_command("observation_end")
        completed = subprocess.run(
            ["adb", "shell", command],
            text=True, capture_output=True, timeout=20)
        record.update(returncode=completed.returncode, stdout=completed.stdout,
                      stderr=completed.stderr)
        try:
            record["device_clock_anchors"] = clock_anchors(completed.stderr)
        except (ValueError, KeyError, TypeError) as error:
            # Preserve raw diagnostics without changing injection success.
            record["device_clock_anchor_error"] = str(error)
        completed.check_returncode()
        receipt_output = completed.stdout
        observation = None
        if observation_command is not None:
            receipt_output, separator, observation = receipt_output.partition(marker)
            if not separator or not observation.strip():
                raise RuntimeError("Missing post-touch observation")
        receipts = [line.split() for line in receipt_output.splitlines()]
        if len(receipts) != len(events) or any(
                len(row) != 3 or int(row[0]) != index or
                int(row[2]) != events[index][1]
                for index, row in enumerate(receipts)):
            raise RuntimeError("Incomplete multi-touch injection receipts")
        event_times = [int(row[1]) for row in receipts]
        if event_times[0] < 0 or any(
                after < before for before, after in zip(event_times, event_times[1:])):
            raise RuntimeError("Invalid multi-touch event clock")
        # Android uptime, shared across app_process invocations. Consecutive
        # cycles can be compared without host/device clock synchronization.
        # These are MotionEvent timestamps, never presentation frame times.
        record["device_first_event_uptime_ms"] = event_times[0]
        record["device_last_event_uptime_ms"] = event_times[-1]
        record["device_event_span_ms"] = event_times[-1] - event_times[0]
        record["planned_event_span_ms"] = events[-1][0] - events[0][0]
        record["success"] = True
        if observation is not None:
            observation = input_completion_observation(
                observation, record.get("device_clock_anchors", []))
            record["route_observation"] = observation
        return observation
    except Exception as error:
        record["error"] = str(error)
        raise
    finally:
        record["host_end_monotonic_s"] = time.monotonic()
        with (Path(output_dir) / "multitouch-commands.jsonl").open("a") as stream:
            stream.write(json.dumps(record) + "\n")
