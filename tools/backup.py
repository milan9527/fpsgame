"""Publish complete, private backup bundles; never print account data."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
FILES = ('postgres.dump', 'results.json', 'results-game2.json')

def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()

def validate(bundle):
    manifest = json.loads((bundle / 'manifest.json').read_text())
    if manifest.get('version') != 1 or set(manifest.get('files', {})) != set(FILES):
        raise ValueError('Unsupported or incomplete backup manifest')
    for name in FILES:
        path = bundle / name
        entry = manifest['files'][name]
        if path.is_symlink() or not path.is_file() or path.stat().st_size != entry['bytes'] or digest(path) != entry['sha256']:
            raise ValueError('Backup integrity check failed: ' + name)
    for name in FILES[1:]:
        if not isinstance(json.loads((bundle / name).read_text()), list):
            raise ValueError('Invalid result queue: ' + name)
    return manifest

def create():
    os.umask(0o077)
    base = ROOT / 'artifacts/backups'
    base.mkdir(parents=True, exist_ok=True)
    identity = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    temporary = base / ('.' + identity + '.partial')
    destination = base / identity
    temporary.mkdir(mode=0o700)
    try:
        with (temporary / 'postgres.dump').open('wb') as output:
            subprocess.run(['docker', 'compose', 'exec', '-T', 'postgres', 'pg_dump', '-U', 'iron', '-d', 'iron', '--format=custom'], cwd=ROOT, stdout=output, check=True)
        for service, filename in [('game', 'results.json'), ('game2', 'results-game2.json')]:
            command = 'if [ -f "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json" ]; then cat "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json"; else printf "[]"; fi'
            with (temporary / filename).open('wb') as output:
                subprocess.run(['docker', 'compose', 'exec', '-T', service, 'sh', '-c', command], cwd=ROOT, stdout=output, check=True)
        manifest = {'version': 1, 'created_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    'build': json.loads((ROOT / 'client/protocol.json').read_text()),
                    'files': {name: {'bytes': (temporary / name).stat().st_size, 'sha256': digest(temporary / name)} for name in FILES},
                    'consistency': 'PostgreSQL snapshot; queues copied afterwards, not a coordinated cross-service snapshot.'}
        (temporary / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        validate(temporary)
        temporary.rename(destination)
    except BaseException:
        shutil.rmtree(temporary)
        raise
    print('Backup saved: ' + str(destination.relative_to(ROOT)))
    return destination

if __name__ == '__main__':
    create()
