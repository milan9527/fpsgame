"""Two independent real Godot clients authenticate and join the dedicated server."""
import os
from pathlib import Path
import subprocess
import uuid
import httpx

root = Path(__file__).resolve().parent.parent
processes = []
try:
    for i in range(2):
        name = 'net_' + uuid.uuid4().hex[:12]
        password = 'network-test-password-729'
        response = httpx.post('http://127.0.0.1:8000/auth/register', json={'username': name, 'password': password})
        response.raise_for_status()
        env = dict(os.environ, TEST_USERNAME=name, TEST_PASSWORD=password, API_URL='http://127.0.0.1:8000')
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
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        log.close()
print('TWO_CLIENT_ONLINE_PASS')
