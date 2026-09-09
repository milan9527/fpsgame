#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
timeout 20s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/pause_rules.gd -- --capture-pause > artifacts/pause-rules.log 2>&1
rg -q PAUSE_RULES_PASS artifacts/pause-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/pause-rules.log; then cat artifacts/pause-rules.log; exit 1; fi
timeout 30s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/weapon_obstruction_rules.gd -- --capture-obstruction > artifacts/weapon-obstruction.log 2>&1
rg -q WEAPON_OBSTRUCTION_RULES_PASS artifacts/weapon-obstruction.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/weapon-obstruction.log; then cat artifacts/weapon-obstruction.log; exit 1; fi
timeout 35s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/weapon_visuals_rules.gd -- --capture-weapons > artifacts/weapon-visuals.log 2>&1
rg -q WEAPON_VISUALS_RULES_PASS artifacts/weapon-visuals.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/weapon-visuals.log; then cat artifacts/weapon-visuals.log; exit 1; fi
timeout 25s ./tools/godot --headless --path client --script ../tests/reliable_actions_rules.gd > artifacts/reliable-actions-rules.log 2>&1
rg -q RELIABLE_ACTIONS_RULES_PASS artifacts/reliable-actions-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/reliable-actions-rules.log; then cat artifacts/reliable-actions-rules.log; exit 1; fi
timeout 25s ./tools/godot --headless --path client --script ../tests/lag_compensation_rules.gd > artifacts/lag-compensation-rules.log 2>&1
rg -q LAG_COMPENSATION_RULES_PASS artifacts/lag-compensation-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/lag-compensation-rules.log; then cat artifacts/lag-compensation-rules.log; exit 1; fi
timeout 35s ./tools/godot --headless --path client --script ../tests/navigation_rules.gd > artifacts/navigation-rules.log 2>&1
rg -q NAVIGATION_RULES_PASS artifacts/navigation-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/navigation-rules.log; then cat artifacts/navigation-rules.log; exit 1; fi
.venv/bin/python tools/test_local_profile.py --capture-ui > artifacts/local-profile-storage.log 2>&1
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
timeout 25s ./tools/godot --headless --path client --script ../tests/grenade_rules.gd > artifacts/grenade-rules.log 2>&1
rg -q GRENADE_RULES_PASS artifacts/grenade-rules.log
if rg -q "SCRIPT ERROR|Assertion failed" artifacts/grenade-rules.log; then cat artifacts/grenade-rules.log; exit 1; fi
timeout 30s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/animation_rules.gd > artifacts/animation-rules.log 2>&1
rg -q ANIMATION_RULES_PASS artifacts/animation-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/animation-rules.log; then cat artifacts/animation-rules.log; exit 1; fi
.venv/bin/python - <<'PY'
import os, subprocess
for line in open('.env'):
    key, value = line.strip().split('=', 1)
    if key == 'SERVER_SECRET':
        os.environ[key] = value
raise SystemExit(subprocess.call(['.venv/bin/pytest', '-q', 'backend/tests/test_integration.py']))
PY
docker compose run --rm --no-deps -v "$PWD/backend/tests:/app/tests:ro" api python -m pytest -q -p no:cacheprovider tests/test_migrations.py
.venv/bin/python tools/test_protocol.py
timeout 20s ./tools/godot --headless --path client --script ../tests/protocol_client.gd > artifacts/protocol-client-test.log 2>&1
rg -q PROTOCOL_CLIENT_PASS artifacts/protocol-client-test.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/protocol-client-test.log; then cat artifacts/protocol-client-test.log; exit 1; fi
.venv/bin/python tools/test_protocol_server.py
timeout 25s env AUDIO_ARTIFACT_DIR="$PWD/artifacts" ./tools/godot --headless --path client --script ../tests/audio_rules.gd > artifacts/audio-rules.log 2>&1
rg -q AUDIO_RULES_PASS artifacts/audio-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/audio-rules.log; then cat artifacts/audio-rules.log; exit 1; fi
timeout 15s ./tools/godot --headless --verbose --path client --script ../tests/audio_shutdown.gd > artifacts/audio-shutdown.log 2>&1
rg -q AUDIO_SHUTDOWN_PENDING artifacts/audio-shutdown.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked|still in use' artifacts/audio-shutdown.log; then cat artifacts/audio-shutdown.log; exit 1; fi
timeout 30s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/viewmodel_rules.gd -- --capture-viewmodel > artifacts/viewmodel-rules.log 2>&1
rg -q VIEWMODEL_RULES_PASS artifacts/viewmodel-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/viewmodel-rules.log; then cat artifacts/viewmodel-rules.log; exit 1; fi
timeout 25s ./tools/godot --headless --path client --script ../tests/spectator_rules.gd > artifacts/spectator-rules.log 2>&1
rg -q SPECTATOR_RULES_PASS artifacts/spectator-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/spectator-rules.log; then cat artifacts/spectator-rules.log; exit 1; fi
timeout 25s ./tools/godot --headless --path client --script ../tests/prediction_rules.gd > artifacts/prediction-rules.log 2>&1
rg -q PREDICTION_RULES_PASS artifacts/prediction-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed' artifacts/prediction-rules.log; then cat artifacts/prediction-rules.log; exit 1; fi
TEST_AUDIO=1 .venv/bin/python tools/test_online.py

TEST_AUDIO=1 .venv/bin/python tools/test_full_round.py
# Restart the single-room server so the delayed clients enter a fresh lobby.
docker compose restart game
.venv/bin/python tools/test_delayed_online.py
docker compose restart game
.venv/bin/python tools/test_delayed_online.py --loss 0.1
