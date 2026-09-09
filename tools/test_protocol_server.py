"""Run an actual dedicated Godot process with an intentionally incompatible manifest."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='iron-protocol-') as directory:
    project = Path(directory) / 'client'
    shutil.copytree(root / 'client', project, ignore=shutil.ignore_patterns('.godot'))
    manifest_path = project / 'protocol.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['protocol'] += 1
    manifest_path.write_text(json.dumps(manifest))
    env = dict(os.environ, API_URL='http://127.0.0.1:8000', XDG_DATA_HOME=str(Path(directory) / 'data'))
    for line in (root / '.env').read_text().splitlines():
        if line.startswith('SERVER_SECRET='):
            env['SERVER_SECRET'] = line.split('=', 1)[1]
    result = subprocess.run([str(root / 'tools/godot'), '--headless', '--path', str(project), '--', '--server'], env=env, capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    assert result.returncode == 1, output
    assert 'Server build is incompatible' in output and 'SERVER_READY' not in output, output
print('PROTOCOL_SERVER_PASS mismatched_process=blocked before_listen=ok')
