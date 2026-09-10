"""Exercise real ENet clients through a local UDP latency/jitter proxy.

Each direction adds 80 +/- 10ms, with optional random packet loss. This is a
bounded integration test, not a capacity or long-duration certification.
"""
import argparse
import heapq
import os
from pathlib import Path
import random
import re
import selectors
import socket
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--loss", type=float, default=0, help="Independent UDP packet drop probability per direction")
    args = parser.parse_args()
    assert 0 <= args.loss <= 0.3
    selector = selectors.DefaultSelector()
    frontend = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    frontend.bind(("127.0.0.1", 27017))
    frontend.setblocking(False)
    selector.register(frontend, selectors.EVENT_READ, None)
    peers = {}
    pending = []
    serial = 0
    counters = {"up": 0, "down": 0, "dropped_up": 0, "dropped_down": 0}
    rng = random.Random(771)
    stop = threading.Event()
    errors = []

    def relay():
        nonlocal serial
        try:
            while not stop.is_set():
                for key, _ in selector.select(0.002):
                    data, address = key.fileobj.recvfrom(65535)
                    if key.fileobj is frontend:
                        if address not in peers:
                            upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                            upstream.bind(("127.0.0.1", 0))
                            upstream.setblocking(False)
                            peers[address] = upstream
                            selector.register(upstream, selectors.EVENT_READ, address)
                        sender, destination = peers[address], ("127.0.0.1", 27015)
                        counters["up"] += 1
                        side = "up"
                    else:
                        sender, destination = frontend, key.data
                        counters["down"] += 1
                        side = "down"
                    if rng.random() < args.loss:
                        counters["dropped_" + side] += 1
                        continue
                    serial += 1
                    heapq.heappush(pending, (time.monotonic() + rng.uniform(0.07, 0.09), serial, sender, destination, data))
                now = time.monotonic()
                while pending and pending[0][0] <= now:
                    _, _, sender, destination, data = heapq.heappop(pending)
                    sender.sendto(data, destination)
        except Exception as exc:
            errors.append(exc)

    thread = threading.Thread(target=relay, daemon=True)
    thread.start()
    try:
        env = dict(os.environ, TEST_GAME_PORT="27017", TEST_ROOM_ID="room-27015", TEST_AUDIO="1")
        result = subprocess.run([str(ROOT / ".venv/bin/python"), "tools/test_online.py"],
                                cwd=ROOT, env=env, capture_output=True, text=True, timeout=65)
        print(result.stdout)
        print(result.stderr)
        assert result.returncode == 0
        assert not errors, errors
        server = (ROOT / "artifacts/online-server.log").read_text()
        ids = re.findall(r"ONLINE_CLIENT_PASS id=(\d+)", result.stdout)
        ages = []
        for peer_id in ids:
            match = re.search(r"REWIND_ACTIVE peer=" + peer_id + r" age_ms=(\d+)", server)
            assert match, f"Server never used historical hit detection for {peer_id}"
            ages.append(int(match.group(1)))
        assert len(ages) == 2 and all(100 <= age <= 200 for age in ages), ages
        assert counters["up"] > 100 and counters["down"] > 100, counters
        if args.loss > 0:
            assert counters["dropped_up"] > 0 and counters["dropped_down"] > 0, counters
        print("DELAYED_ONLINE_PASS one_way_ms=70..90 loss=", args.loss, "rewind_ms=", ages, "packets=", counters)
    finally:
        stop.set()
        thread.join(timeout=2)
        selector.close()
        frontend.close()
        for upstream in peers.values():
            upstream.close()


if __name__ == "__main__":
    main()
