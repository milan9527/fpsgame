"""Real independent Godot processes exercise an isolated local result ledger."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--packed', action='store_true')
parser.add_argument('--capture-ui', action='store_true')
options = parser.parse_args()
if options.packed:
    command = [str(ROOT / 'artifacts/IronMeridian-Linux/play.sh'), '--headless']
else:
    command = [str(ROOT / 'tools/godot'), '--headless', '--path', str(ROOT / 'client')]
command += ['--script', str(ROOT / 'tests/local_profile_worker.gd'), '--']

with tempfile.TemporaryDirectory(prefix='meridian-profile-') as folder:
    base = Path(folder)
    env = dict(os.environ, LOCAL_TEST_ROOT=folder)

    def invoke(*args, expected=0):
        run = subprocess.run(command + list(args), env=env, capture_output=True, text=True, timeout=15)
        assert run.returncode == expected, run.stdout + run.stderr
        assert 'SCRIPT ERROR' not in run.stdout + run.stderr, run.stdout + run.stderr
        return run.stdout

    def summary():
        return json.loads(next(line.removeprefix('LOCAL_PROFILE_JSON ') for line in invoke('read').splitlines() if line.startswith('LOCAL_PROFILE_JSON ')))

    ids = [str(uuid.uuid4()) for _ in range(4)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as workers:
        list(workers.map(lambda identifier: invoke('write', identifier, '2'), ids[:2]))
    result = summary()
    assert result['completed'] == 2 and result['kills'] == 4
    # Same operation can race without overwriting or double counting.
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as workers:
        list(workers.map(lambda _: invoke('write', ids[2], '2'), range(2)))
    assert summary()['completed'] == 3
    original = (base / 'records' / ids[2] / 'result.json').read_bytes()
    invoke('write', ids[2], '3', expected=2)
    assert (base / 'records' / ids[2] / 'result.json').read_bytes() == original
    invoke('write', '../escape', '2', expected=2)
    invoke('write', ids[3], '999', expected=2)
    assert summary()['completed'] == 3
    # An interrupted unpublished transaction is never counted.
    pending = base / 'pending' / 'interrupted'
    pending.mkdir()
    (pending / 'result.json').write_bytes(original)
    assert summary()['completed'] == 3
    primary = base / 'records' / ids[0] / 'result.json'
    primary.write_text('{broken')
    result = summary()
    assert result['completed'] == 3 and result['recovered'] == 1
    (primary.parent / 'backup.json').write_text('{also broken')
    result = summary()
    assert result['completed'] == 2 and result['unreadable'] == 1
    future = base / 'records' / ids[1] / 'result.json'
    future.write_text(json.dumps({'version': 99}))
    result = summary()
    assert result['completed'] == 1 and result['newer'] == 1
    invoke('write', ids[1], '2', expected=2)
    assert json.loads(future.read_text())['version'] == 99
    # Checksum and schema are both verified, even for parseable JSON.
    valid_dir = base / 'records' / ids[2]
    envelope = json.loads(original)
    record = json.loads(envelope['payload'])
    record['kills'] = 3
    envelope['payload'] = json.dumps(record)
    for file in ('result.json', 'backup.json'):
        (valid_dir / file).write_text(json.dumps(envelope))
    assert summary()['unreadable'] == 2, 'Changed payload must fail checksum validation'
    record['kills'] = True
    envelope['payload'] = json.dumps(record)
    envelope['sha256'] = hashlib.sha256(envelope['payload'].encode()).hexdigest()
    for file in ('result.json', 'backup.json'):
        (valid_dir / file).write_text(json.dumps(envelope))
    assert summary()['unreadable'] == 2
    # Existing published records remain byte-for-byte intact on rejected writes.
    assert primary.read_text() == '{broken'
    assert pending.exists()
    ui_command = command.copy()
    ui_command[ui_command.index(str(ROOT / 'tests/local_profile_worker.gd'))] = str(ROOT / 'tests/local_profile_ui.gd')
    separator = ui_command.index('--')
    ui_command[separator:separator] = ['--audio-driver', 'Dummy']
    if options.capture_ui:
        ui_command.remove('--headless')
        ui_command = ['xvfb-run', '-a', *ui_command, '--capture-local']
    ui_env = dict(env, LOCAL_TEST_ROOT=str(base / 'ui'), LOCAL_CAPTURE_PATH=str(ROOT / 'artifacts/local-history.png'))
    ui = subprocess.run(ui_command, env=ui_env, capture_output=True, text=True, timeout=30)
    assert ui.returncode == 0 and 'LOCAL_PROFILE_UI_PASS' in ui.stdout, ui.stdout + ui.stderr
    assert not any(error in ui.stdout + ui.stderr for error in ['SCRIPT ERROR', 'ObjectDB instances leaked']), ui.stdout + ui.stderr
    print(ui.stdout)
    duo_command = ui_command.copy()
    duo_command[duo_command.index(str(ROOT / 'tests/local_profile_ui.gd'))] = str(ROOT / 'tests/local_duo_profile.gd')
    duo_env = dict(env, LOCAL_TEST_ROOT=str(base / 'duo'), LOCAL_CAPTURE_PATH=str(ROOT / 'artifacts/local-duo-history.png'))
    duo = subprocess.run(duo_command, env=duo_env, capture_output=True, text=True, timeout=30)
    assert duo.returncode == 0 and 'LOCAL_DUO_PROFILE_PASS' in duo.stdout, duo.stdout + duo.stderr
    assert not any(error in duo.stdout + duo.stderr for error in ['SCRIPT ERROR', 'ObjectDB instances leaked']), duo.stdout + duo.stderr
    reopened = subprocess.run(command + ['read'], env=duo_env, capture_output=True, text=True, timeout=15)
    assert reopened.returncode == 0 and 'SCRIPT ERROR' not in reopened.stdout + reopened.stderr
    ledger = json.loads(next(line.removeprefix('LOCAL_PROFILE_JSON ') for line in reopened.stdout.splitlines() if line.startswith('LOCAL_PROFILE_JSON ')))
    assert ledger['modes']['solo']['completed'] == 1 and ledger['modes']['duo']['completed'] == 3
    assert ledger['modes']['duo']['abandoned'] == 1 and len(ledger['records']) == 5
    print(duo.stdout)

print('LOCAL_PROFILE_STORAGE_PASS independent_processes=ok concurrent=ok idempotent=ok conflict=ok path_validation=ok partial_publish=ok recovery=ok future_version=ok strict_schema=ok')
