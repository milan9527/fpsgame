#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
timeout 25s ./tools/godot --headless --path client -- --smoke > artifacts/offline-smoke.log 2>&1
# Godot assertion failures need a log check as well as exit-code checking.
rg -q OFFLINE_SMOKE_PASS artifacts/offline-smoke.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/offline-smoke.log; then
  cat artifacts/offline-smoke.log
  exit 1
fi
.venv/bin/python - <<'PY'
import os, subprocess
for line in open('.env'):
    key, value = line.strip().split('=', 1)
    if key == 'SERVER_SECRET':
        os.environ[key] = value
raise SystemExit(subprocess.call(['.venv/bin/pytest', '-q', 'backend/tests']))
PY
.venv/bin/python tools/test_online.py

.venv/bin/python tools/test_full_round.py
