"""Check damaged bundles fail before container creation, using a real backup."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch
from backup import validate, digest
from restore_drill import drill

bundle = Path(sys.argv[1]).resolve()
validate(bundle)
with tempfile.TemporaryDirectory(prefix='iron-backup-test-') as temporary:
    root = Path(temporary)
    for case in ['changed_dump', 'missing_queue', 'invalid_queue', 'unknown_version']:
        copy = root / case
        shutil.copytree(bundle, copy)
        manifest_path = copy / 'manifest.json'
        manifest = json.loads(manifest_path.read_text())
        if case == 'changed_dump':
            with (copy / 'postgres.dump').open('ab') as stream:
                stream.write(b'corrupt')
        elif case == 'missing_queue':
            (copy / 'results.json').unlink()
        elif case == 'invalid_queue':
            path = copy / 'results.json'
            path.write_text('{}')
            manifest['files']['results.json'] = {'bytes': path.stat().st_size, 'sha256': digest(path)}
        else:
            manifest['version'] = 999
        manifest_path.write_text(json.dumps(manifest))
        report = root / (case + '.report.json')
        with patch.object(subprocess, 'run', side_effect=AssertionError('Corrupt bundle must not invoke Docker')):
            try:
                drill(copy, report)
            except ValueError:
                pass
            else:
                raise AssertionError('Invalid backup accepted: ' + case)
        assert not report.exists()
print('BACKUP_INTEGRITY_PASS corruption=ok missing=ok queue_shape=ok version=ok no_container=ok')
