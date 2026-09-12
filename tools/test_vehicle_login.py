"""Backend-authenticated clients exercise authoritative human and bot vehicle gameplay."""
import json
import argparse
import os
from pathlib import Path
import subprocess
import socket
import re
import time
import hashlib

import httpx
from test_accounts import account
from udp_impairment import ImpairedUDP
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:8001"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["solo", "duo"], default="solo")
    parser.add_argument("--departure", choices=["revoke", "drop"], default="")
    parser.add_argument("--impaired", action="store_true",
                        help="50–100 ms one-way latency, 3%% loss and three-second uplink outage")
    parser.add_argument("--audio", action="store_true", help="Verify vehicle emitters on both network clients")
    parser.add_argument("--combat", action="store_true", help="Third authenticated client shoots the moving driver")
    parser.add_argument("--spectator", action="store_true", help="Eliminated duo teammate follows the network driver")
    parser.add_argument("--bot-driver", action="store_true", help="Authenticated passenger rides with its server-assigned bot teammate")
    parser.add_argument("--bot-turn", choices=["left", "right"], default="", help="Exercise a curved evacuation route with the bot teammate")
    parser.add_argument("--client-fps", type=int, choices=[30, 60, 120], default=0)
    parser.add_argument("--latency-ms", type=int, default=0, help="Constant one-way UDP delay without packet loss")
    parser.add_argument("--candidate-dir", type=Path, help="Run server and all clients from a verified candidate PCK")
    options = parser.parse_args()
    mode = options.mode
    if options.bot_turn and not options.bot_driver:
        parser.error("--bot-turn requires --bot-driver")
    if options.bot_driver and (mode != "duo" or options.spectator or options.combat or options.departure or options.impaired):
        parser.error("Bot driver requires a separate duo passenger scenario")
    if options.spectator and (mode != "duo" or options.combat or options.departure):
        parser.error("Spectator requires duo and is separate from combat/departure")
    if not 0 <= options.latency_ms <= 200 or (options.latency_ms and options.impaired):
        parser.error("Latency must be 0–200 ms and cannot be combined with --impaired")
    if options.combat and (options.departure or options.impaired):
        parser.error("Moving combat is tested separately from outage/departure")
    count = 3 if options.combat or options.spectator else 2
    if options.bot_driver:
        count = 1
    if options.impaired and options.departure:
        parser.error("Network recovery and driver departure are separate scenarios")
    suffix = "-" + options.departure if options.departure else ""
    if options.impaired:
        suffix += "-impaired"
    if options.audio:
        suffix += "-audio"
    if options.combat:
        suffix += "-combat"
    account_suffix = suffix
    if options.bot_driver:
        suffix += "-bot-driver"
        if options.bot_turn:
            suffix += "-turn-" + options.bot_turn
        account_suffix = ""
    if options.spectator:
        suffix += "-spectator"
        account_suffix = "-combat"  # Reuse three existing accounts; session tickets remain fresh.
    if options.client_fps:
        suffix += f"-fps{options.client_fps}"
    if options.latency_ms:
        suffix += f"-delay{options.latency_ms}"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = str(probe.getsockname()[1])
    candidate = None
    runtime = [str(ROOT / "tools/godot"), "--headless", "--path", str(ROOT / "client")]
    if options.candidate_dir:
        runtime, candidate = candidate_command(options.candidate_dir)
        manifest = candidate["manifest"]
        suffix += "-packed-" + candidate["commit"][:8]
    else:
        manifest = json.loads((ROOT / "client/protocol.json").read_text())
    response = httpx.get(BASE + "/protocol")
    response.raise_for_status()
    assert response.json() == manifest, "Development API must match the selected runtime manifest"
    credentials = [account(f"vehicle-login-{mode}{account_suffix}-{i}", base=BASE) for i in range(count)]
    env = dict(os.environ, GAME_PORT=port, GAME_MODE=mode, API_URL=BASE,
               VEHICLE_DEPARTURE=options.departure,
               VEHICLE_IMPAIRED="1" if options.impaired else "",
               VEHICLE_COMBAT="1" if options.combat else "",
               VEHICLE_SPECTATOR="1" if options.spectator else "",
               VEHICLE_BOT_DRIVER="1" if options.bot_driver else "",
               VEHICLE_BOT_TURN=options.bot_turn,
               XDG_DATA_HOME=str(ROOT / f"artifacts/vehicle-login-{mode}-server-data"))
    env["SERVER_SECRET"] = next(line.split("=", 1)[1] for line in
                               (ROOT / "artifacts/duo-dev.env").read_text().splitlines()
                               if line.startswith("DUO_SERVER_SECRET="))
    entries = []
    relays = []

    def launch(role, script, variables, flags):
        path = ROOT / f"artifacts/vehicle-login-{mode}{suffix}-{role}.log"
        stream = path.open("w")
        process = subprocess.Popen(runtime + ["--script", str(ROOT / "tests" / script),
                                              "--", *flags],
                                   cwd=ROOT, env=variables, stdout=stream,
                                   stderr=subprocess.STDOUT)
        entries.append((process, stream, path, role))
        return process, path

    try:
        server, path = launch("server", "vehicle_login_server.gd", env, ["--server"])
        deadline = time.monotonic() + 25
        while "SERVER_READY" not in path.read_text():
            assert server.poll() is None and time.monotonic() < deadline, path
            time.sleep(0.1)
        for i, identity in enumerate(credentials):
            client_port = port
            if options.impaired or options.latency_ms:
                settings = {} if options.impaired else {
                    "delay_range": (options.latency_ms / 1000,) * 2, "loss_probability": 0}
                relay = ImpairedUDP(port, seed=4100 + i, **settings)
                relays.append(relay)
                client_port = str(relay.port)
            variables = dict(os.environ, TEST_USERNAME=identity["username"],
                             TEST_PASSWORD=identity["password"], TEST_GAME_PORT=client_port,
                             TEST_ROOM_ID="room-" + port,
                             TEST_GAME_MODE=mode, API_URL=BASE,
                             VEHICLE_DEPARTURE=options.departure,
                             VEHICLE_IMPAIRED="1" if options.impaired else "",
                             VEHICLE_AUDIO_TEST="1" if options.audio else "",
                             VEHICLE_COMBAT="1" if options.combat else "",
                             VEHICLE_SPECTATOR="1" if options.spectator else "",
                             VEHICLE_BOT_DRIVER="1" if options.bot_driver else "",
                             VEHICLE_BOT_TURN=options.bot_turn,
                             VEHICLE_CLIENT_FPS=str(options.client_fps),
                             XDG_DATA_HOME=str(ROOT / f"artifacts/vehicle-login-client-{i}-data"))
            launch(f"client-{i}", "vehicle_login_client.gd", variables, ["--bot-client"])
        deadline = time.monotonic() + 70
        departed_index = -1
        outage_started = False
        while any(process.poll() is None for process, _, _, _ in entries):
            assert time.monotonic() < deadline, "Vehicle login integration timed out"
            for _, _, log_path, _ in entries:
                text = log_path.read_text()
                assert "SCRIPT ERROR:" not in text, f"{log_path}\n{text[-3000:]}"
            if options.impaired and not outage_started and "VEHICLE_NETWORK_BLACKOUT_READY" in path.read_text():
                outage_started = True
                for relay in relays:
                    relay.blackout_until = time.monotonic() + 3.0
            ready = re.search(r"VEHICLE_DEPARTURE_READY uid=([0-9a-f-]+)", path.read_text())
            if options.departure and departed_index < 0 and ready:
                departed_index = next(i for i, identity in enumerate(credentials)
                                      if identity["user_id"] == ready.group(1))
                if options.departure == "drop":
                    entries[departed_index + 1][0].kill()
                else:
                    headers = {"Authorization": "Bearer " + credentials[departed_index]["token"]}
                    httpx.post(BASE + "/auth/logout-all", headers=headers).raise_for_status()
                    assert httpx.get(BASE + "/profile", headers=headers).status_code == 401
            time.sleep(0.2)
        for process, stream, path, role in entries:
            stream.flush()
            text = path.read_text()
            assert not any(value in text for value in
                           ("ERROR:", "Assertion failed", "ObjectDB instances leaked")), text[-4000:]
            marker = "VEHICLE_LOGIN_SERVER_PASS" if role == "server" else "VEHICLE_LOGIN_CLIENT_PASS"
            if options.combat and "VEHICLE_COMBAT_SHOOTER_PASS" in text:
                marker = "VEHICLE_COMBAT_SHOOTER_PASS"
            if options.spectator and "VEHICLE_NETWORK_SPECTATOR_PASS" in text:
                marker = "VEHICLE_NETWORK_SPECTATOR_PASS"
            if role == f"client-{departed_index}" and options.departure:
                if options.departure == "drop":
                    assert process.returncode == -9
                    continue
                marker = "VEHICLE_REVOKED_CLIENT_PASS"
            assert process.returncode == 0 and marker in text, f"Failed: {path}\n{text[-4000:]}"
            if options.audio and marker == "VEHICLE_LOGIN_CLIENT_PASS":
                assert "VEHICLE_NETWORK_AUDIO_PASS" in text, path
            if options.client_fps and role != "server":
                samples = re.findall(r"VEHICLE_FRAME_RATE requested=\d+ measured=([\d.]+)", text)
                assert samples, f"No measured frame rate: {path}"
                assert all(options.client_fps * 0.8 <= float(fps) <= options.client_fps * 1.1
                           for fps in samples), (path, samples)
        if options.departure:
            assert departed_index >= 0 and "VEHICLE_DEPARTURE_RELEASED" in entries[0][2].read_text()
            if options.departure == "revoke":
                assert "VEHICLE_REVOCATION_INPUT_CLEARED" in entries[0][2].read_text()
        if options.combat:
            assert "VEHICLE_COMBAT_SERVER_HIT" in entries[0][2].read_text()
            assert entries[0][2].read_text().count("AUTHENTICATED peer=") == count
            assert sum("VEHICLE_COMBAT_SHOOTER_PASS" in entry[2].read_text() for entry in entries) == 1
            assert sum("VEHICLE_COMBAT_OCCUPANT_PASS" in entry[2].read_text() for entry in entries) == 2
        if options.spectator:
            assert entries[0][2].read_text().count("AUTHENTICATED peer=") == 3
            assert "VEHICLE_SPECTATOR_SERVER_READY" in entries[0][2].read_text()
            assert sum("VEHICLE_NETWORK_SPECTATOR_PASS" in entry[2].read_text() for entry in entries) == 1
        if options.bot_driver:
            assert entries[0][2].read_text().count("AUTHENTICATED peer=") == 1
            assert "VEHICLE_BOT_DRIVER_SERVER_PASS" in entries[0][2].read_text()
            assert "VEHICLE_BOT_PASSENGER_PASS" in entries[1][2].read_text()
        if options.bot_turn:
            poses = []
            for entry in entries:
                match = re.search(r"VEHICLE_BOT_TURN_POSE (.+)", entry[2].read_text())
                assert match, entry[2]
                poses.append(json.loads(match.group(1)))
            assert sum((a-b)**2 for a,b in zip(poses[0]["position"], poses[1]["position"])) < 0.09, poses
            assert abs(poses[0]["yaw"] - poses[1]["yaw"]) < 0.03, poses
        if relays:
            if options.impaired:
                assert outage_started and "VEHICLE_NETWORK_RECOVERED" in entries[0][2].read_text()
            for relay in relays:
                relay.close()
                assert not relay.errors, relay.errors
                for side in ("up", "down"):
                    assert relay.stats[side]["forwarded"] > 100
                    if options.impaired:
                        assert relay.stats[side]["random_drops"] > 0
                        assert relay.stats[side]["reordered_schedule"] > 0
                    else:
                        assert relay.stats[side]["random_drops"] == 0
                if options.impaired:
                    assert relay.stats["up"]["outage_drops"] > 0
                else:
                    assert relay.stats["up"]["outage_drops"] == 0
            report = {"one_way_delay_ms": [50, 100] if options.impaired else [options.latency_ms] * 2,
                      "loss_probability": 0.03 if options.impaired else 0,
                      "uplink_outage_seconds": 3 if options.impaired else 0,
                      "client_fps_cap": options.client_fps, "relays": [r.stats for r in relays]}
            (ROOT / f"artifacts/vehicle-login-{mode}{suffix}-network.json").write_text(json.dumps(report, indent=2) + "\n")
            relays.clear()
        if candidate:
            _, verified = candidate_command(options.candidate_dir)
            assert verified["sha256"] == candidate["sha256"]
        evidence = {
            "status": "passed", "manifest": manifest, "mode": mode, "clients": count,
            "candidate": {"commit": candidate["commit"], "archive_sha256": candidate["sha256"],
                          "pck_sha256": candidate["pck_sha256"]} if candidate else None,
            "scenario": {key: getattr(options, key) for key in
                         ("departure", "impaired", "audio", "combat", "spectator",
                          "bot_driver", "bot_turn", "client_fps", "latency_ms")},
            "logs": [str(entry[2].relative_to(ROOT)) for entry in entries],
            "fixture_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                               for name in ("tools/test_vehicle_login.py", "tests/vehicle_login_server.gd",
                                            "tests/vehicle_login_client.gd")},
            "scope": "Backend admission and bounded vehicle scenario; not a full match or public-network soak test",
        }
        (ROOT / f"artifacts/vehicle-login-{mode}{suffix}-verification.json").write_text(
            json.dumps(evidence, indent=2) + "\n")
        print(f"VEHICLE_LOGIN_PASS mode={mode} departure={options.departure or 'none'} impaired={options.impaired} backend_auth=ok tickets=ok clients={count} driving=ok passenger=ok brake=ok exits=ok")
    finally:
        for process, stream, _, _ in entries:
            if process.poll() is None:
                process.kill()
                process.wait()
            stream.close()
        for relay in relays:
            relay.close()


if __name__ == "__main__":
    main()
