"""Backend login + two real clients exercise authoritative vehicle gameplay."""
import json
import argparse
import os
from pathlib import Path
import subprocess
import socket
import re
import time

import httpx
from test_accounts import account
from udp_impairment import ImpairedUDP

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
    options = parser.parse_args()
    mode = options.mode
    if options.combat and (options.departure or options.impaired):
        parser.error("Moving combat is tested separately from outage/departure")
    count = 3 if options.combat else 2
    if options.impaired and options.departure:
        parser.error("Network recovery and driver departure are separate scenarios")
    suffix = "-" + options.departure if options.departure else ""
    if options.impaired:
        suffix += "-impaired"
    if options.audio:
        suffix += "-audio"
    if options.combat:
        suffix += "-combat"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = str(probe.getsockname()[1])
    manifest = json.loads((ROOT / "client/protocol.json").read_text())
    response = httpx.get(BASE + "/protocol")
    response.raise_for_status()
    assert response.json() == manifest, "Development API must match source build"
    credentials = [account(f"vehicle-login-{mode}{suffix}-{i}", base=BASE) for i in range(count)]
    runtime = [str(ROOT / "tools/godot"), "--headless", "--path", str(ROOT / "client")]
    env = dict(os.environ, GAME_PORT=port, GAME_MODE=mode, API_URL=BASE,
               VEHICLE_DEPARTURE=options.departure,
               VEHICLE_IMPAIRED="1" if options.impaired else "",
               VEHICLE_COMBAT="1" if options.combat else "",
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
            if options.impaired:
                relay = ImpairedUDP(port, seed=4100 + i)
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
            if role == f"client-{departed_index}" and options.departure:
                if options.departure == "drop":
                    assert process.returncode == -9
                    continue
                marker = "VEHICLE_REVOKED_CLIENT_PASS"
            assert process.returncode == 0 and marker in text, f"Failed: {path}\n{text[-4000:]}"
            if options.audio and marker == "VEHICLE_LOGIN_CLIENT_PASS":
                assert "VEHICLE_NETWORK_AUDIO_PASS" in text, path
        if options.departure:
            assert departed_index >= 0 and "VEHICLE_DEPARTURE_RELEASED" in entries[0][2].read_text()
            if options.departure == "revoke":
                assert "VEHICLE_REVOCATION_INPUT_CLEARED" in entries[0][2].read_text()
        if options.combat:
            assert "VEHICLE_COMBAT_SERVER_HIT" in entries[0][2].read_text()
            assert entries[0][2].read_text().count("AUTHENTICATED peer=") == count
            assert sum("VEHICLE_COMBAT_SHOOTER_PASS" in entry[2].read_text() for entry in entries) == 1
            assert sum("VEHICLE_COMBAT_OCCUPANT_PASS" in entry[2].read_text() for entry in entries) == 2
        if options.impaired:
            assert outage_started and "VEHICLE_NETWORK_RECOVERED" in entries[0][2].read_text()
            for relay in relays:
                relay.close()
                assert not relay.errors, relay.errors
                for side in ("up", "down"):
                    assert relay.stats[side]["forwarded"] > 100
                    assert relay.stats[side]["random_drops"] > 0
                    assert relay.stats[side]["reordered_schedule"] > 0
                assert relay.stats["up"]["outage_drops"] > 0
            report = {"one_way_delay_ms": [50, 100], "loss_probability": 0.03,
                      "uplink_outage_seconds": 3, "relays": [r.stats for r in relays]}
            (ROOT / f"artifacts/vehicle-login-{mode}{suffix}-network.json").write_text(json.dumps(report, indent=2) + "\n")
            relays.clear()
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
