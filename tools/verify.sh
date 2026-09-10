#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
timeout 15s ./tools/godot --headless --path client --script ../tests/input_timeout_rules.gd > artifacts/input-timeout-rules.log 2>&1
rg -q INPUT_TIMEOUT_RULES_PASS artifacts/input-timeout-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/input-timeout-rules.log; then cat artifacts/input-timeout-rules.log; exit 1; fi
timeout 15s ./tools/godot --headless --path client --script ../tests/damage_indicators_rules.gd > artifacts/damage-indicators.log 2>&1
rg -q DAMAGE_INDICATORS_PASS artifacts/damage-indicators.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/damage-indicators.log; then cat artifacts/damage-indicators.log; exit 1; fi
timeout 25s ./tools/godot --headless --path client --script ../tests/bot_cover_rules.gd > artifacts/bot-cover-rules.log 2>&1
rg -q BOT_COVER_RULES_PASS artifacts/bot-cover-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/bot-cover-rules.log; then cat artifacts/bot-cover-rules.log; exit 1; fi
timeout 40s ./tools/godot --headless --path client --script ../tests/training_rules.gd > artifacts/training-rules.log 2>&1
rg -q TRAINING_RULES_PASS artifacts/training-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/training-rules.log; then cat artifacts/training-rules.log; exit 1; fi
timeout 30s ./tools/godot --headless --path client --script ../tests/checkpoint_rules.gd > artifacts/checkpoint-rules.log 2>&1
rg -q CHECKPOINT_RULES_PASS artifacts/checkpoint-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/checkpoint-rules.log; then cat artifacts/checkpoint-rules.log; exit 1; fi
.venv/bin/python tools/test_checkpoint_process.py > artifacts/checkpoint-process.log 2>&1
timeout 30s ./tools/godot --headless --path client --script ../tests/bindings_rules.gd > artifacts/bindings-rules.log 2>&1
rg -q BINDINGS_RULES_PASS artifacts/bindings-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/bindings-rules.log; then cat artifacts/bindings-rules.log; exit 1; fi
timeout 30s ./tools/godot --headless --path client --script ../tests/fall_rules.gd > artifacts/fall-rules.log 2>&1
rg -q FALL_RULES_PASS artifacts/fall-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/fall-rules.log; then cat artifacts/fall-rules.log; exit 1; fi
timeout 30s ./tools/godot --headless --path client --script ../tests/smoke_grenade_rules.gd > artifacts/smoke-grenade-rules.log 2>&1
rg -q SMOKE_GRENADE_RULES_PASS artifacts/smoke-grenade-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/smoke-grenade-rules.log; then cat artifacts/smoke-grenade-rules.log; exit 1; fi
timeout 30s ./tools/godot --headless --path client --script ../tests/lean_rules.gd > artifacts/lean-rules.log 2>&1
rg -q LEAN_RULES_PASS artifacts/lean-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/lean-rules.log; then cat artifacts/lean-rules.log; exit 1; fi
timeout 30s ./tools/godot --headless --path client --script ../tests/zone_terrain_rules.gd > artifacts/zone-terrain-rules.log 2>&1
rg -q ZONE_TERRAIN_RULES_PASS artifacts/zone-terrain-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/zone-terrain-rules.log; then cat artifacts/zone-terrain-rules.log; exit 1; fi
timeout 25s ./tools/godot --headless --path client --script ../tests/zone_rules.gd > artifacts/zone-rules.log 2>&1
rg -q ZONE_RULES_PASS artifacts/zone-rules.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/zone-rules.log; then cat artifacts/zone-rules.log; exit 1; fi
timeout 25s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/supply_rules.gd -- --capture-supplies > artifacts/supply-rules.log 2>&1
rg -q SUPPLY_RULES_PASS artifacts/supply-rules.log
timeout 25s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/magazine_rules.gd -- --capture-magazines > artifacts/magazine-rules.log 2>&1
rg -q MAGAZINE_RULES_PASS artifacts/magazine-rules.log
timeout 25s ./tools/godot --headless --path client --script ../tests/death_loot_rules.gd > artifacts/death-loot-rules.log 2>&1
rg -q DEATH_LOOT_RULES_PASS artifacts/death-loot-rules.log
timeout 25s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/inventory_rules.gd -- --capture-inventory > artifacts/inventory-rules.log 2>&1
rg -q INVENTORY_RULES_PASS artifacts/inventory-rules.log
timeout 25s ./tools/godot --headless --path client --script ../tests/drop_rules.gd > artifacts/drop-rules.log 2>&1
rg -q DROP_RULES_PASS artifacts/drop-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/drop-rules.log; then cat artifacts/drop-rules.log; exit 1; fi
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/inventory-rules.log; then cat artifacts/inventory-rules.log; exit 1; fi
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/death-loot-rules.log; then cat artifacts/death-loot-rules.log; exit 1; fi
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/magazine-rules.log; then cat artifacts/magazine-rules.log; exit 1; fi
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/supply-rules.log; then cat artifacts/supply-rules.log; exit 1; fi
.venv/bin/python tools/test_supply_network.py
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
raise SystemExit(subprocess.call(['.venv/bin/pytest', '-q', 'backend/tests/test_integration.py', 'backend/tests/test_validation_privacy.py']))
PY
docker compose run --rm --no-deps -v "$PWD/backend/tests:/app/tests:ro" api python -m pytest -q -p no:cacheprovider tests/test_migrations.py
docker compose run --rm --no-deps -v "$PWD/backend/tests:/app/tests:ro" api python -m pytest -q -p no:cacheprovider tests/test_rooms.py
docker compose run --rm --no-deps -v "$PWD/backend/tests:/app/tests:ro" api python -m pytest -q -p no:cacheprovider tests/test_availability.py
.venv/bin/python tools/test_room_api.py
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
# Empty-room recycling returns the primary server to a fresh generation.
.venv/bin/python tools/test_delayed_online.py
.venv/bin/python tools/test_delayed_online.py --loss 0.1

.venv/bin/python tools/test_death_loot_network.py
.venv/bin/python tools/test_inventory_network.py
.venv/bin/python tools/test_drop_network.py

.venv/bin/python tools/test_multiroom.py
.venv/bin/python tools/test_room_failure.py
timeout 25s ./tools/godot --headless --path client --script ../tests/cancel_connection_rules.gd > artifacts/cancel-connection-rules.log 2>&1
rg -q CANCEL_CONNECTION_RULES_PASS artifacts/cancel-connection-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/cancel-connection-rules.log; then cat artifacts/cancel-connection-rules.log; exit 1; fi
.venv/bin/python tools/test_cancel_connection.py
timeout 25s xvfb-run -a ./tools/godot --path client --audio-driver Dummy --script ../tests/tactical_map_rules.gd -- --capture-map > artifacts/tactical-map-rules.log 2>&1
rg -q TACTICAL_MAP_RULES_PASS artifacts/tactical-map-rules.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/tactical-map-rules.log; then cat artifacts/tactical-map-rules.log; exit 1; fi
.venv/bin/python tools/test_map_network.py

.venv/bin/python tools/test_smoke_network.py

.venv/bin/python tools/test_fall_network.py

.venv/bin/python tools/test_bindings_network.py

.venv/bin/python tools/test_input_timeout.py
