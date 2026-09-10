"""Two independent real Godot clients authenticate and join the dedicated server."""
import os
from pathlib import Path
import subprocess
import re
import time
from test_accounts import account

root = Path(__file__).resolve().parent.parent
processes = []
peer_ids = []
try:
    for i in range(2):
        credentials = account('network-' + str(i))
        name = credentials['username']
        password = credentials['password']
        env = dict(os.environ, TEST_USERNAME=name, TEST_PASSWORD=password, API_URL='http://127.0.0.1:8000', TEST_ROOM_ID=os.getenv('TEST_ROOM_ID', 'room-27015'))
        log_path = root / 'artifacts' / f'online-client-{i}.log'
        log = open(log_path, 'w')
        proc = subprocess.Popen([str(root / 'tools/godot'), '--headless', '--path', str(root / 'client'), '--', '--bot-client'], env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append((proc, log, log_path))
    for proc, log, path in processes:
        code = proc.wait(timeout=50)
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
(root / 'artifacts' / 'online-server.log').write_text(server_output)
assert 'Unable to send packet' not in server_output, server_output
assert 'SCRIPT ERROR' not in server_output, server_output
# Readiness is emitted once at startup, which may precede the two-minute
# disconnect/error window when testing an already-running service.
startup_output = subprocess.check_output(
    ['docker', 'compose', 'logs', '--no-color', 'game'], cwd=root, text=True)
ready_lines = [line for line in startup_output.splitlines() if 'SERVER_READY ' in line]
assert ready_lines and 'relay=false' in ready_lines[-1], 'Dedicated server must disable client-to-client relay'
print('TWO_CLIENT_ONLINE_PASS disconnect=ok')
