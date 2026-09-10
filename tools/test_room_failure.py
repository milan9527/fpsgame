"""Stop an empty second room and verify expiry/re-registration of the real process."""
import json
from pathlib import Path
import subprocess
import time

import httpx
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
build = json.loads((ROOT / 'client/protocol.json').read_text())
credentials = account('room-failure')
auth = {'Authorization': 'Bearer ' + credentials['token']}
query = "from app.main import cache; print(cache.get('im:rooms:room:room-27022') or '{}')"


def state():
    return json.loads(subprocess.check_output(['docker', 'compose', 'exec', '-T', 'api',
                                               'python', '-c', query], cwd=ROOT, text=True))


before = state()
assert before.get('phase') == 'waiting' and not before.get('players'), 'Failure test requires an empty waiting room'
try:
    subprocess.run(['docker', 'compose', 'stop', 'game2'], cwd=ROOT, check=True, capture_output=True)
    time.sleep(13)
    assert not state(), 'Dead process remained in directory beyond heartbeat TTL'
    response = httpx.post('http://127.0.0.1:8000/matchmaking/rooms/join',
                          json=dict(build, room_id='room-27022'), headers=auth)
    assert response.status_code == 503, response.text
finally:
    subprocess.run(['docker', 'compose', 'start', 'game2'], cwd=ROOT, check=True, capture_output=True)
for attempt in range(40):
    current = state()
    if current.get('phase') == 'waiting' and current.get('instance_id') != before['instance_id']:
        break
    time.sleep(0.25)
else:
    raise AssertionError('Restarted server failed to register a new instance')
print('ROOM_FAILURE_PASS real_process_stopped=ok expired=ok matchmaking_rejected=ok new_instance_restored=ok')
