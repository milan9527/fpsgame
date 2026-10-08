"""Two independent real Godot clients authenticate and join the dedicated server."""
import os
from pathlib import Path
import subprocess
import re
import time
import argparse
import httpx
from test_accounts import account
from candidate_runtime import candidate_command

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--candidate-dir", type=Path)
parser.add_argument("--preview", type=Path, help="Local exported executable to test")
parser.add_argument("--output", type=Path, help="Directory for client/server evidence")
parser.add_argument("--timeout", type=int, default=50)
options = parser.parse_args()
if options.preview and options.candidate_dir:
    parser.error("--preview and --candidate-dir are mutually exclusive")
if options.timeout <= 0:
    parser.error("--timeout must be positive")
output_dir = (options.output or root / "artifacts").resolve()
output_dir.mkdir(parents=True, exist_ok=True)
runtime = [str(root / 'tools/godot'), '--headless', '--path', str(root / 'client')]
if options.preview:
    preview = options.preview.resolve()
    if not preview.is_file() or not preview.with_suffix(".pck").is_file():
        parser.error("preview executable and PCK must exist")
    runtime = [str(preview), "--headless", "--path", "/tmp"]
prefix = ""
candidate = None
if options.candidate_dir:
    runtime, candidate = candidate_command(options.candidate_dir)
    response = httpx.get('http://127.0.0.1:8000/protocol')
    response.raise_for_status()
    assert response.json() == candidate["manifest"]
    prefix = "candidate-" + candidate["commit"][:8] + "-"
processes = []
peer_ids = []
try:
    for i in range(2):
        credentials = account('network-' + str(i))
        name = credentials['username']
        password = credentials['password']
        env = dict(os.environ, TEST_USERNAME=name, TEST_PASSWORD=password, API_URL='http://127.0.0.1:8000', TEST_ROOM_ID=os.getenv('TEST_ROOM_ID', 'room-27015'))
        log_path = output_dir / f'{prefix}online-client-{i}.log'
        log = open(log_path, 'w')
        proc = subprocess.Popen(runtime + ['--', '--bot-client'], env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append((proc, log, log_path))
    for proc, log, path in processes:
        code = proc.wait(timeout=options.timeout)
        log.close()
        output = path.read_text()
        print(output)
        assert code == 0 and 'ONLINE_CLIENT_PASS' in output, f'Client failed: {path}'
        assert 'ObjectDB instances leaked' not in output and 'SCRIPT ERROR' not in output, output
        peer_ids.append(re.search(r'ONLINE_CLIENT_PASS id=(\d+)', output).group(1))
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        log.close()
for _ in range(100):
    server_output = subprocess.check_output(['docker', 'compose', 'logs', '--no-color', '--since', '2m', 'game'], cwd=root, text=True)
    if all('PEER_DISCONNECTED peer=' + peer in server_output for peer in peer_ids):
        break
    time.sleep(0.2)
else:
    raise AssertionError('Server did not confirm both disconnects')
(output_dir / (prefix + 'online-server.log')).write_text(server_output)
assert 'Unable to send packet' not in server_output, server_output
assert 'SCRIPT ERROR' not in server_output, server_output
# Readiness is emitted once at startup, which may precede the two-minute
# disconnect/error window when testing an already-running service.
startup_output = subprocess.check_output(
    ['docker', 'compose', 'logs', '--no-color', 'game'], cwd=root, text=True)
ready_lines = [line for line in startup_output.splitlines() if 'SERVER_READY ' in line]
assert ready_lines and 'relay=false' in ready_lines[-1], 'Dedicated server must disable client-to-client relay'
print('TWO_CLIENT_ONLINE_PASS disconnect=ok')
if candidate:
    candidate_command(options.candidate_dir)
    print("PUBLISHED_CANDIDATE_ONLINE_PASS commit=" + candidate["commit"] + " sha256=" + candidate["sha256"])
