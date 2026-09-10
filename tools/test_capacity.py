"""Real sixteen-process ENet capacity gate; localhost/headless, not a WAN benchmark."""
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import time
import httpx
from test_accounts import account, FILE

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / ('capacity-' + str(time.time_ns()))
OUT.mkdir()
BARRIER = OUT / 'start'
BUILD = json.loads((ROOT / 'client/protocol.json').read_text())
ROOM = 'room-27015'
STARTED = datetime.datetime.now(datetime.timezone.utc).isoformat()
BAD = ('ERROR:', 'SCRIPT ERROR', 'Assertion failed', 'ObjectDB instances leaked', 'above the MTU', 'Unable to send packet')
processes = []

def room_state():
    query = "import json; from app.main import cache; print(cache.get('im:rooms:room:room-27015') or '{}')"
    return json.loads(subprocess.check_output(['docker', 'compose', 'exec', '-T', 'api', 'python', '-c', query], cwd=ROOT, text=True))

def wait_for(marker, timeout):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        texts = [path.read_text() for _, _, path in processes]
        for (proc, _, path), text in zip(processes, texts):
            if proc.poll() is not None or any(error in text for error in BAD):
                raise AssertionError('Client failed (exit=%s): ' % proc.poll() + str(path) + '\n' + text[-2500:])
        if all(marker in text for text in texts):
            return texts
        time.sleep(.2)
    raise AssertionError('Timeout waiting for ' + marker + '; inspect ' + str(OUT))

try:
    # Respect the production login limiter; repeated local load runs share one IP.
    for attempt in range(35):
        query = "import json; from app.main import cache; print(json.dumps([(int(cache.get(k) or 0), cache.ttl(k)) for k in cache.scan_iter('login:*')]))"
        rates = json.loads(subprocess.check_output(['docker', 'compose', 'exec', '-T', 'api', 'python', '-c', query], cwd=ROOT, text=True))
        if all(count <= 13 or ttl <= 0 for count, ttl in rates):
            break
        if attempt == 0:
            print('Waiting for existing login-rate window to expire', flush=True)
        time.sleep(2)
    else:
        raise AssertionError('Login capacity unavailable; other authentication traffic remains active')
    state = room_state()
    assert state.get('phase') == 'waiting' and not state.get('players'), 'Capacity test requires an empty waiting room'
    credentials = []
    for i in range(16):
        slot = 'capacity-' + str(i)
        records = json.loads(FILE.read_text()) if FILE.exists() else {}
        credentials.append(records[slot] if slot in records else account(slot))
    outsider = account('capacity-outsider')
    for i, identity in enumerate(credentials):
        env = dict(os.environ, TEST_USERNAME=identity['username'], TEST_PASSWORD=identity['password'],
                   TEST_ROOM_ID=ROOM, API_URL='http://127.0.0.1:8000', CAPACITY_BARRIER=str(BARRIER))
        path = OUT / ('client-%02d.log' % i)
        log = path.open('w')
        proc = subprocess.Popen([str(ROOT / 'tools/godot'), '--headless', '--max-fps', '30', '--path', 'client',
                                 '--script', '../tests/capacity_client.gd', '--', '--bot-client'],
                                cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append((proc, log, path))
    ready = wait_for('CAPACITY_READY', 65)
    peers = [re.search(r'CAPACITY_READY peer=(\d+)', text).group(1) for text in ready]
    matches = {re.search(r'match=([0-9a-f-]+)', text).group(1) for text in ready}
    assert len(set(peers)) == 16 and len(matches) == 1
    state = room_state()
    assert len(state['players']) == 16 and state['phase'] == 'live'
    response = httpx.post('http://127.0.0.1:8000/matchmaking/rooms/join', json=dict(BUILD, room_id=ROOM),
                          headers={'Authorization': 'Bearer ' + outsider['token']})
    assert response.status_code == 503, 'A live full room admitted an extra player'
    BARRIER.touch()
    texts = wait_for('CAPACITY_CLIENT_PASS', 30)
    Path(str(BARRIER) + '.exit').touch()
    for proc, log, path in processes:
        assert proc.wait(timeout=15) == 0, str(path)
        log.close()
        assert not any(error in path.read_text() for error in BAD), str(path)
    for _ in range(40):
        state = room_state()
        if state.get('phase') == 'waiting' and not state.get('players') and state.get('generation') not in matches:
            break
        time.sleep(.25)
    else:
        raise AssertionError('Full room failed to recycle after clients left')
    logs = subprocess.check_output(['docker', 'compose', 'logs', '--no-color', '--since', STARTED, 'game'], cwd=ROOT, text=True)
    (OUT / 'server.log').write_text(logs)
    assert not any(error in logs for error in BAD)
    assert all('PEER_DISCONNECTED peer=' + peer in logs for peer in peers)
    report = {'build': BUILD, 'clients': 16, 'independent_peers': len(set(peers)), 'matches': list(matches),
              'overflow_status': response.status_code, 'room_recycled': True,
              'results': [re.search(r'CAPACITY_CLIENT_PASS[^\n]+', text).group(0) for text in texts],
              'limits': 'Single host, headless, eight seconds of active input; not 16 people, rendered FPS, WAN, or endurance.'}
    (OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('CAPACITY_16_PASS ' + str(OUT), flush=True)
finally:
    Path(str(BARRIER) + '.exit').touch()
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        log.close()
    if not (OUT / 'server.log').exists():
        diagnostic = subprocess.run(['docker', 'compose', 'logs', '--no-color', '--since', STARTED, 'game'],
                                    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (OUT / 'server.log').write_text(diagnostic.stdout)
