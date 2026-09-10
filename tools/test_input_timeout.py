"""Pause a real client's input sender while keeping the ENet connection alive."""
import os
from pathlib import Path
import subprocess
import time
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
container = subprocess.check_output(['docker', 'compose', 'ps', '-q', 'game'], cwd=ROOT, text=True).strip()
started = subprocess.check_output(['docker', 'inspect', '--format', '{{.State.StartedAt}}', container], text=True).strip()
for _ in range(60):
    logs = subprocess.check_output(['docker', 'compose', 'logs', '--no-color', '--since', started, 'game'], cwd=ROOT, text=True)
    if 'SERVER_READY ' in logs:
        break
    time.sleep(.5)
else:
    raise RuntimeError('Dedicated server has not completed room registration')
identity = account('network-0')
env = dict(os.environ, TEST_USERNAME=identity['username'], TEST_PASSWORD=identity['password'],
           TEST_ROOM_ID='room-27015', API_URL='http://127.0.0.1:8000')
path = ROOT / 'artifacts/input-timeout-client.log'
with path.open('w') as output:
    result = subprocess.run([str(ROOT / 'tools/godot'), '--headless', '--path', 'client',
                             '--script', '../tests/input_timeout_client.gd', '--', '--bot-client'],
                            cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=45)
text = path.read_text()
assert result.returncode == 0 and 'INPUT_TIMEOUT_NETWORK_PASS' in text, str(path)
assert not any(error in text for error in ['SCRIPT ERROR', 'Assertion failed', 'ObjectDB instances leaked']), str(path)
print('INPUT_TIMEOUT_ENET_PASS ' + str(path))
