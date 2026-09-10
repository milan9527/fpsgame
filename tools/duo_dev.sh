#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
python3 - <<'PY'
import os
from pathlib import Path
import secrets
path = Path('artifacts/duo-dev.env')
if not path.exists():
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        for key in ['DUO_POSTGRES_PASSWORD', 'DUO_JWT_SECRET', 'DUO_SERVER_SECRET']:
            output.write(key + '=' + secrets.token_hex(32) + '\n')
path.chmod(0o600)
PY
docker compose --env-file artifacts/duo-dev.env -f compose.duo-dev.yaml up -d --build
