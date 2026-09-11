"""Backend login + two real clients exercise authoritative vehicle gameplay."""
import json
import argparse
import os
from pathlib import Path
import subprocess
import socket
import time

import httpx
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:8001"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["solo", "duo"], default="solo")
    mode = parser.parse_args().mode
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = str(probe.getsockname()[1])
    manifest = json.loads((ROOT / "client/protocol.json").read_text())
    response = httpx.get(BASE + "/protocol")
    response.raise_for_status()
    assert response.json() == manifest, "Development API must match source build"
    credentials = [account(f"vehicle-login-{mode}-{i}", base=BASE) for i in range(2)]
    runtime = [str(ROOT / "tools/godot"), "--headless", "--path", str(ROOT / "client")]
    env = dict(os.environ, GAME_PORT=port, GAME_MODE=mode, API_URL=BASE,
               XDG_DATA_HOME=str(ROOT / f"artifacts/vehicle-login-{mode}-server-data"))
    env["SERVER_SECRET"] = next(line.split("=", 1)[1] for line in
                               (ROOT / "artifacts/duo-dev.env").read_text().splitlines()
                               if line.startswith("DUO_SERVER_SECRET="))
    entries = []

    def launch(role, script, variables, flags):
        path = ROOT / f"artifacts/vehicle-login-{mode}-{role}.log"
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
            variables = dict(os.environ, TEST_USERNAME=identity["username"],
                             TEST_PASSWORD=identity["password"], TEST_GAME_PORT=port,
                             TEST_GAME_MODE=mode, API_URL=BASE,
                             XDG_DATA_HOME=str(ROOT / f"artifacts/vehicle-login-client-{i}-data"))
            launch(f"client-{i}", "vehicle_login_client.gd", variables, ["--bot-client"])
        deadline = time.monotonic() + 70
        while any(process.poll() is None for process, _, _, _ in entries):
            assert time.monotonic() < deadline, "Vehicle login integration timed out"
            time.sleep(0.2)
        for process, stream, path, role in entries:
            stream.flush()
            text = path.read_text()
            marker = "VEHICLE_LOGIN_SERVER_PASS" if role == "server" else "VEHICLE_LOGIN_CLIENT_PASS"
            assert process.returncode == 0 and marker in text, f"Failed: {path}\n{text[-4000:]}"
            assert not any(value in text for value in
                           ("ERROR:", "Assertion failed", "ObjectDB instances leaked")), text[-4000:]
        print(f"VEHICLE_LOGIN_PASS mode={mode} backend_auth=ok tickets=ok clients=2 driving=ok passenger=ok brake=ok exits=ok")
    finally:
        for process, stream, _, _ in entries:
            if process.poll() is None:
                process.kill()
                process.wait()
            stream.close()


if __name__ == "__main__":
    main()
