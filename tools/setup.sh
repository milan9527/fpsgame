#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f .env ]; then
  python3 - <<'PY'
import os,secrets
fd=os.open('.env',os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
with os.fdopen(fd,'w') as f:
    for key in ('POSTGRES_PASSWORD','JWT_SECRET','SERVER_SECRET'):
        f.write(f'{key}={secrets.token_hex(32)}\n')
    f.write('GAME_PUBLIC_HOST=127.0.0.1\n')
PY
fi
if [ ! -x tools/godot ]; then
  curl -fL https://github.com/godotengine/godot-builds/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip -o /tmp/iron-godot.zip
  python3 -m zipfile -e /tmp/iron-godot.zip tools
  mv tools/Godot_v4.4.1-stable_linux.x86_64 tools/godot
  chmod +x tools/godot
fi
docker compose up -d --build
