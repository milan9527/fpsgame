"""Two real dedicated services and clients must produce independent live rounds."""
import os
import json
import time
from pathlib import Path
import re
import subprocess

from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
processes = []
try:
    for index, room in enumerate(['room-27015', 'room-27022']):
        credentials = account('multiroom-' + str(index))
        env = dict(os.environ, TEST_USERNAME=credentials['username'], TEST_PASSWORD=credentials['password'],
                   TEST_ROOM_ID=room, API_URL='http://127.0.0.1:8000')
        path = ROOT / f'artifacts/multiroom-client-{index}.log'
        log = path.open('w')
        process = subprocess.Popen([str(ROOT / 'tools/godot'), '--headless', '--path', 'client',
                                    '--script', '../tests/multiroom_client.gd', '--', '--bot-client'],
                                   cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append((process, log, path))
    matches = []
    for process, log, path in processes:
        code = process.wait(timeout=50)
        log.close()
        text = path.read_text()
        print(text)
        assert code == 0 and 'MULTIROOM_CLIENT_PASS' in text
        assert not any(e in text for e in ['SCRIPT ERROR', 'Assertion failed', 'ObjectDB instances leaked'])
        matches.append(re.search(r'match=([0-9a-f-]+)', text).group(1))
    assert matches[0] != matches[1]
    query = "import json; from app.main import cache; print(json.dumps([json.loads(cache.get('im:rooms:room:'+room) or '{}') for room in ['room-27015','room-27022']]))"
    for attempt in range(30):
        states = json.loads(subprocess.check_output(['docker', 'compose', 'exec', '-T', 'api', 'python', '-c', query], cwd=ROOT, text=True))
        if all(state.get('phase') == 'waiting' and not state.get('players') and state.get('generation') not in matches for state in states):
            break
        time.sleep(0.2)
    else:
        raise AssertionError('Empty rooms did not return to admission with new generations')
    print('MULTIROOM_PASS actual_servers=2 actual_clients=2 distinct_rounds=ok roster_isolation=ok empty_reuse=ok')
finally:
    for process, log, _ in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
        log.close()
