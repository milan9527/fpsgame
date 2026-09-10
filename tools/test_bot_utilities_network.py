"""A dedicated bot scavenges and uses smoke, observed by a real ENet client."""
import os
from pathlib import Path
import subprocess
import time
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
identity = account('network-0')
env = dict(os.environ, GAME_PORT='27031', API_URL='http://127.0.0.1:8000',
           XDG_DATA_HOME=str(ROOT/'artifacts/bot-utilities-server-data'))
env['SERVER_SECRET'] = next(line.split('=', 1)[1] for line in (ROOT/'.env').read_text().splitlines() if line.startswith('SERVER_SECRET='))
server_path = ROOT/'artifacts/bot-utilities-network-server.log'
with server_path.open('w') as log:
    server = subprocess.Popen([str(ROOT/'tools/godot'), '--headless', '--path', 'client', '--script',
                               '../tests/bot_utilities_network_server.gd', '--', '--server'],
                              cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(250):
            if 'SERVER_READY' in server_path.read_text():
                break
            assert server.poll() is None, str(server_path)
            time.sleep(.1)
        else:
            raise AssertionError('Dedicated fixture readiness timeout')
        variables = dict(os.environ, TEST_USERNAME=identity['username'], TEST_PASSWORD=identity['password'],
                         TEST_GAME_PORT='27031', API_URL='http://127.0.0.1:8000')
        path = ROOT/'artifacts/bot-utilities-network-client.log'
        with path.open('w') as output:
            result = subprocess.run([str(ROOT/'tools/godot'), '--headless', '--path', 'client', '--script',
                                     '../tests/bot_utilities_network_client.gd', '--', '--bot-client'],
                                    cwd=ROOT, env=variables, stdout=output, stderr=subprocess.STDOUT, timeout=35)
        assert result.returncode == 0 and 'BOT_UTILITIES_NETWORK_PASS' in path.read_text(), str(path)
        assert 'BOT_UTILITIES_SERVER_PASS' in server_path.read_text(), str(server_path)
        for file in [path, server_path]:
            assert not any(error in file.read_text() for error in ['SCRIPT ERROR', 'Assertion failed', 'ObjectDB instances leaked', 'Snapshot exceeds target']), str(file)
        print('BOT_UTILITIES_REAL_NETWORK_PASS server_tactics=ok client_replication=ok')
    finally:
        server.terminate()
        server.wait(timeout=10)
