"""Real ENet latency and a bounded downstream outage exercise the player HUD."""
import heapq
import os
from pathlib import Path
import selectors
import signal
import socket
import subprocess
import threading
import time
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
identity = account('network-0')
selector = selectors.DefaultSelector()
frontend = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
frontend.bind(('127.0.0.1', 27030))
upstream.bind(('127.0.0.1', 0))
for sock in [frontend, upstream]:
    sock.setblocking(False)
    selector.register(sock, selectors.EVENT_READ)
stop = threading.Event()
blackout = threading.Event()
counters = {'up': 0, 'down': 0, 'dropped_down': 0}
errors = []

def relay():
    client = None
    pending = []
    serial = 0
    try:
        while not stop.is_set():
            for key, _ in selector.select(.002):
                data, address = key.fileobj.recvfrom(65535)
                if key.fileobj is frontend:
                    client = address
                    side, sender, destination = 'up', upstream, ('127.0.0.1', 27015)
                else:
                    side, sender, destination = 'down', frontend, client
                counters[side] += 1
                if side == 'down' and blackout.is_set():
                    counters['dropped_down'] += 1
                    continue
                if destination:
                    serial += 1
                    heapq.heappush(pending, (time.monotonic() + .075, serial, sender, destination, data))
            while pending and pending[0][0] <= time.monotonic():
                _, _, sender, destination, data = heapq.heappop(pending)
                sender.sendto(data, destination)
    except Exception as error:
        errors.append(error)

thread = threading.Thread(target=relay, daemon=True)
thread.start()
path = ROOT/'artifacts/network-status-client.log'
try:
    env = dict(os.environ, TEST_USERNAME=identity['username'], TEST_PASSWORD=identity['password'],
               TEST_GAME_PORT='27030', TEST_ROOM_ID='room-27015', API_URL='http://127.0.0.1:8000',
               CAPTURE_PATH=str(ROOT/'artifacts/network-status-stalled.png'))
    with path.open('w') as log:
        client = subprocess.Popen(['xvfb-run', '-a', str(ROOT/'tools/godot'), '--path', 'client',
                                   '--audio-driver', 'Dummy', '--script', '../tests/network_status_client.gd',
                                   '--', '--bot-client'], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            for _ in range(400):
                if 'NETWORK_MONITOR_READY' in path.read_text():
                    break
                assert client.poll() is None, str(path)
                time.sleep(.1)
            else:
                raise AssertionError('Client readiness timeout')
            blackout.set()
            time.sleep(1.8)
            assert 'NETWORK_MONITOR_STALLED' in path.read_text(), str(path)
            blackout.clear()
            assert client.wait(timeout=15) == 0
            text = path.read_text()
            assert 'NETWORK_MONITOR_REAL_PROXY_PASS' in text, str(path)
            assert not any(error in text for error in ['SCRIPT ERROR', 'Assertion failed', 'ObjectDB instances leaked']), str(path)
            assert not errors and counters['dropped_down'] > 0
            print('NETWORK_STATUS_PROXY_PASS one_way_ms=75 downstream_blackout_seconds=1.8', counters)
        finally:
            blackout.clear()
            if client.poll() is None:
                os.killpg(client.pid, signal.SIGTERM)
                client.wait(timeout=10)
finally:
    stop.set()
    thread.join(timeout=2)
    selector.close()
    frontend.close()
    upstream.close()
