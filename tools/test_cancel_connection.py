"""Actual graphical client cancels an allocated but deliberately unreachable connection."""
import os
from pathlib import Path
import socket
import subprocess
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
credentials = account('cancel-connection')
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sink:
    sink.bind(('127.0.0.1', 0))
    env = dict(os.environ, TEST_USERNAME=credentials['username'], TEST_PASSWORD=credentials['password'],
               TEST_ROOM_ID='room-27022', TEST_GAME_PORT=str(sink.getsockname()[1]), API_URL='http://127.0.0.1:8000')
    path = ROOT / 'artifacts/cancel-network-client.log'
    with path.open('w') as output:
        result = subprocess.run(['xvfb-run', '-a', str(ROOT / 'tools/godot'), '--audio-driver', 'Dummy',
                                 '--path', 'client', '--script', '../tests/cancel_network_client.gd', '--', '--bot-client'],
                                cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=25)
    text = path.read_text()
    print(text)
    assert result.returncode == 0 and 'CANCEL_NETWORK_CLIENT_PASS' in text
    assert not any(error in text for error in ['SCRIPT ERROR', 'Assertion failed', 'ObjectDB instances leaked'])
    print('CANCEL_CONNECTION_PASS graphical_client=ok real_redis_reservation=ok cancellation=ok')
