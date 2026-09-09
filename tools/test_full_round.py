"""A separate accelerated real server completes a match and persists its result."""
import os
from pathlib import Path
import subprocess
import time
from test_accounts import account as test_account
import httpx

root = Path(__file__).resolve().parent.parent
base = 'http://127.0.0.1:8000'
env = dict(os.environ, GAME_PORT='27016', API_URL=base, XDG_DATA_HOME=str(root / 'artifacts' / 'round-data'))
for line in (root / '.env').read_text().splitlines():
    key, value = line.split('=', 1)
    if key == 'SERVER_SECRET':
        env[key] = value
account = test_account('full-round')
name = account['username']
password = account['password']
profile_headers = {'Authorization': 'Bearer ' + account['token']}
before_matches = httpx.get(base + '/profile', headers=profile_headers).json()['matches']
server_log = open(root / 'artifacts/full-round-server.log', 'w')
client_log = open(root / 'artifacts/full-round-client.log', 'w')
server = subprocess.Popen([str(root / 'tools/godot'), '--headless', '--path', str(root / 'client'), '--time-scale', '20', '--', '--server'], env=env, stdout=server_log, stderr=subprocess.STDOUT)
client = None
try:
    for _ in range(100):
        if 'SERVER_READY' in (root / 'artifacts/full-round-server.log').read_text():
            break
        if server.poll() is not None:
            raise RuntimeError('Test server exited')
        time.sleep(0.1)
    else:
        raise RuntimeError('Test server did not start')
    client_env = dict(os.environ, TEST_USERNAME=name, TEST_PASSWORD=password, TEST_GAME_PORT='27016', API_URL=base)
    client = subprocess.Popen([str(root / 'tools/godot'), '--headless', '--path', str(root / 'client'), '--', '--bot-client', '--round-client'], env=client_env, stdout=client_log, stderr=subprocess.STDOUT)
    assert client.wait(timeout=50) == 0
    client_output = (root / 'artifacts/full-round-client.log').read_text()
    assert 'FULL_ROUND_CLIENT_PASS' in client_output, client_output
    headers = {'Authorization': 'Bearer ' + account['token']}
    for _ in range(60):
        profile = httpx.get(base + '/profile', headers=headers).json()
        if profile['matches'] == before_matches + 1:
            break
        time.sleep(0.2)
    else:
        raise AssertionError('Completed match was not persisted')
    server_output = (root / 'artifacts/full-round-server.log').read_text()
    assert 'SCRIPT ERROR' not in server_output, server_output
    assert 'above the MTU' not in server_output, server_output
    print(client_output)
    print('FULL_ROUND_PERSISTENCE_PASS', {k: profile[k] for k in ('matches', 'kills', 'wins')})
finally:
    for proc in (client, server):
        if proc is not None and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
    server_log.close()
    client_log.close()
