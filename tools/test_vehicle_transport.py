#!/usr/bin/env python3
"""Verify vehicle replication through real ENet processes (no HTTP admission)."""
import os
from pathlib import Path
import socket
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    env = dict(os.environ, VEHICLE_TEST_PORT=str(port))
    command = [str(ROOT / "tools/godot"), "--headless", "--path",
               str(ROOT / "client"), "--script", "../tests/vehicle_transport.gd"]
    processes = []
    logs = []
    try:
        for role in ("server", "client"):
            path = ROOT / f"artifacts/vehicle-transport-{role}.log"
            stream = path.open("w")
            logs.append((path, stream, role))
            args = command + (["--", "--fixture-server"] if role == "server" else [])
            processes.append(subprocess.Popen(args, cwd=ROOT, env=env,
                                              stdout=stream, stderr=subprocess.STDOUT))
            if role == "server":
                time.sleep(0.6)
        for process in processes:
            assert process.wait(timeout=25) == 0, "ENet fixture process failed"
        for path, stream, role in logs:
            stream.flush()
            text = path.read_text()
            assert f"VEHICLE_TRANSPORT_{role.upper()}_PASS" in text, text
            assert not any(marker in text for marker in
                           ("ERROR:", "Assertion failed", "ObjectDB instances leaked")), text
        print("VEHICLE_TRANSPORT_PASS real_enet=ok server_broadcast=ok client_pairing=ok")
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for _, stream, _ in logs:
            stream.close()


if __name__ == "__main__":
    main()
