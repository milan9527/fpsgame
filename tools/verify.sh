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
timeout 25s ./tools/godot --headless --path client --script ../tests/combat_rules.gd > artifacts/combat-rules.log 2>&1
rg -q COMBAT_RULES_PASS artifacts/combat-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/combat-rules.log; then cat artifacts/combat-rules.log; exit 1; fi
timeout 30s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/animation_rules.gd > artifacts/animation-rules.log 2>&1
rg -q ANIMATION_RULES_PASS artifacts/animation-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/animation-rules.log; then cat artifacts/animation-rules.log; exit 1; fi
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
