#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts/IronMeridian-Linux
./tools/godot --headless --path client --export-pack Linux ../artifacts/IronMeridian-Linux/IronMeridian.pck
cp tools/godot artifacts/IronMeridian-Linux/IronMeridian
cp docs/PLAYER_GUIDE.md artifacts/IronMeridian-Linux/PLAYER_GUIDE.md
mkdir -p artifacts/IronMeridian-Linux/docs
cp docs/LOCAL_RESULTS.md artifacts/IronMeridian-Linux/docs/LOCAL_RESULTS.md
cp docs/LAG_COMPENSATION.md artifacts/IronMeridian-Linux/docs/LAG_COMPENSATION.md
cp docs/PROTOCOL.md artifacts/IronMeridian-Linux/docs/PROTOCOL.md
cp docs/WEAPON_VISUALS.md artifacts/IronMeridian-Linux/docs/WEAPON_VISUALS.md
cp docs/SUPPLIES.md artifacts/IronMeridian-Linux/docs/SUPPLIES.md
cp docs/AMMUNITION.md artifacts/IronMeridian-Linux/docs/AMMUNITION.md
cp docs/DEATH_LOOT.md artifacts/IronMeridian-Linux/docs/DEATH_LOOT.md
cp docs/INVENTORY.md artifacts/IronMeridian-Linux/docs/INVENTORY.md
cp docs/DROPPING.md artifacts/IronMeridian-Linux/docs/DROPPING.md
cp docs/ROOM_DIRECTORY.md artifacts/IronMeridian-Linux/docs/ROOM_DIRECTORY.md
cp docs/CONNECTION_LIFECYCLE.md artifacts/IronMeridian-Linux/docs/CONNECTION_LIFECYCLE.md
cp docs/TACTICAL_MAP.md artifacts/IronMeridian-Linux/docs/TACTICAL_MAP.md
cp LICENSE artifacts/IronMeridian-Linux/LICENSE
cat > artifacts/IronMeridian-Linux/play.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec ./IronMeridian --main-pack IronMeridian.pck "$@"
SH
chmod +x artifacts/IronMeridian-Linux/play.sh
cp docs/SAFE_ZONES.md artifacts/IronMeridian-Linux/docs/SAFE_ZONES.md
cp docs/LEANING.md artifacts/IronMeridian-Linux/docs/LEANING.md
cp docs/SMOKE_GRENADES.md artifacts/IronMeridian-Linux/docs/SMOKE_GRENADES.md
cp docs/FALL_DAMAGE.md artifacts/IronMeridian-Linux/docs/FALL_DAMAGE.md
cp docs/CONTROLS.md artifacts/IronMeridian-Linux/docs/CONTROLS.md
cp docs/SOLO_CHECKPOINTS.md artifacts/IronMeridian-Linux/docs/SOLO_CHECKPOINTS.md
cp docs/ATTACHMENTS.md artifacts/IronMeridian-Linux/docs/ATTACHMENTS.md
cp docs/ACCOUNT_SESSIONS.md artifacts/IronMeridian-Linux/docs/ACCOUNT_SESSIONS.md
cp docs/DEATH_RECAP.md artifacts/IronMeridian-Linux/docs/DEATH_RECAP.md
cp docs/NETWORK_STATUS.md artifacts/IronMeridian-Linux/docs/NETWORK_STATUS.md
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/network_status_rules.gd" > artifacts/packed-network-status.log 2>&1
rg -q NETWORK_STATUS_RULES_PASS artifacts/packed-network-status.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-network-status.log; then cat artifacts/packed-network-status.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/death_recap_rules.gd" > artifacts/packed-death-recap.log 2>&1
rg -q DEATH_RECAP_RULES_PASS artifacts/packed-death-recap.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-death-recap.log; then cat artifacts/packed-death-recap.log; exit 1; fi
cp docs/BOT_COVER.md artifacts/IronMeridian-Linux/docs/BOT_COVER.md
cp docs/TRAINING.md artifacts/IronMeridian-Linux/docs/TRAINING.md
timeout 20s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/foregrip_rules.gd" > artifacts/packed-foregrip.log 2>&1
rg -q FOREGRIP_RULES_PASS artifacts/packed-foregrip.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-foregrip.log; then cat artifacts/packed-foregrip.log; exit 1; fi
timeout 15s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/input_timeout_rules.gd" > artifacts/packed-input-timeout.log 2>&1
rg -q INPUT_TIMEOUT_RULES_PASS artifacts/packed-input-timeout.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-input-timeout.log; then cat artifacts/packed-input-timeout.log; exit 1; fi
timeout 15s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/damage_indicators_rules.gd" > artifacts/packed-damage-indicators.log 2>&1
rg -q DAMAGE_INDICATORS_PASS artifacts/packed-damage-indicators.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-damage-indicators.log; then cat artifacts/packed-damage-indicators.log; exit 1; fi
timeout 40s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/training_rules.gd" > artifacts/packed-training.log 2>&1
rg -q TRAINING_RULES_PASS artifacts/packed-training.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-training.log; then cat artifacts/packed-training.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/bot_cover_rules.gd" > artifacts/packed-bot-cover.log 2>&1
rg -q BOT_COVER_RULES_PASS artifacts/packed-bot-cover.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-bot-cover.log; then cat artifacts/packed-bot-cover.log; exit 1; fi
timeout 30s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/checkpoint_rules.gd" > artifacts/packed-checkpoint.log 2>&1
rg -q CHECKPOINT_RULES_PASS artifacts/packed-checkpoint.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-checkpoint.log; then cat artifacts/packed-checkpoint.log; exit 1; fi
.venv/bin/python tools/test_checkpoint_process.py --packed > artifacts/packed-checkpoint-process.log 2>&1
timeout 30s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/bindings_rules.gd" > artifacts/packed-bindings.log 2>&1
rg -q BINDINGS_RULES_PASS artifacts/packed-bindings.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-bindings.log; then cat artifacts/packed-bindings.log; exit 1; fi
timeout 30s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/fall_rules.gd" > artifacts/packed-fall.log 2>&1
rg -q FALL_RULES_PASS artifacts/packed-fall.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-fall.log; then cat artifacts/packed-fall.log; exit 1; fi
timeout 30s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/smoke_grenade_rules.gd" > artifacts/packed-smoke-grenade.log 2>&1
rg -q SMOKE_GRENADE_RULES_PASS artifacts/packed-smoke-grenade.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-smoke-grenade.log; then cat artifacts/packed-smoke-grenade.log; exit 1; fi
timeout 30s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/lean_rules.gd" > artifacts/packed-lean.log 2>&1
rg -q LEAN_RULES_PASS artifacts/packed-lean.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-lean.log; then cat artifacts/packed-lean.log; exit 1; fi
timeout 30s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/zone_terrain_rules.gd" > artifacts/packed-zone-terrain.log 2>&1
rg -q ZONE_TERRAIN_RULES_PASS artifacts/packed-zone-terrain.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-zone-terrain.log; then cat artifacts/packed-zone-terrain.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/zone_rules.gd" > artifacts/packed-zones.log 2>&1
rg -q ZONE_RULES_PASS artifacts/packed-zones.log
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-zones.log; then cat artifacts/packed-zones.log; exit 1; fi
# A packed-project smoke run checks imported GLB assets and resource paths.
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/supply_rules.gd" > artifacts/packed-supplies.log 2>&1
rg -q SUPPLY_RULES_PASS artifacts/packed-supplies.log
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/magazine_rules.gd" > artifacts/packed-magazines.log 2>&1
rg -q MAGAZINE_RULES_PASS artifacts/packed-magazines.log
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/death_loot_rules.gd" > artifacts/packed-death-loot.log 2>&1
rg -q DEATH_LOOT_RULES_PASS artifacts/packed-death-loot.log
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/inventory_rules.gd" > artifacts/packed-inventory.log 2>&1
rg -q INVENTORY_RULES_PASS artifacts/packed-inventory.log
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/drop_rules.gd" > artifacts/packed-drop.log 2>&1
rg -q DROP_RULES_PASS artifacts/packed-drop.log
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/cancel_connection_rules.gd" > artifacts/packed-cancel-connection.log 2>&1
rg -q CANCEL_CONNECTION_RULES_PASS artifacts/packed-cancel-connection.log
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/tactical_map_rules.gd" > artifacts/packed-tactical-map.log 2>&1
rg -q TACTICAL_MAP_RULES_PASS artifacts/packed-tactical-map.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-tactical-map.log; then cat artifacts/packed-tactical-map.log; exit 1; fi
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-cancel-connection.log; then cat artifacts/packed-cancel-connection.log; exit 1; fi
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-drop.log; then cat artifacts/packed-drop.log; exit 1; fi
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-inventory.log; then cat artifacts/packed-inventory.log; exit 1; fi
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-death-loot.log; then cat artifacts/packed-death-loot.log; exit 1; fi
if rg -q "SCRIPT ERROR|Assertion failed|ObjectDB instances leaked" artifacts/packed-magazines.log; then cat artifacts/packed-magazines.log; exit 1; fi
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-supplies.log; then cat artifacts/packed-supplies.log; exit 1; fi
timeout 20s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/pause_rules.gd" > artifacts/packed-pause.log 2>&1
rg -q PAUSE_RULES_PASS artifacts/packed-pause.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-pause.log; then cat artifacts/packed-pause.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/weapon_obstruction_rules.gd" > artifacts/packed-weapon-obstruction.log 2>&1
rg -q WEAPON_OBSTRUCTION_RULES_PASS artifacts/packed-weapon-obstruction.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-weapon-obstruction.log; then cat artifacts/packed-weapon-obstruction.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/weapon_visuals_rules.gd" > artifacts/packed-weapon-visuals.log 2>&1
rg -q WEAPON_VISUALS_RULES_PASS artifacts/packed-weapon-visuals.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-weapon-visuals.log; then cat artifacts/packed-weapon-visuals.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/reliable_actions_rules.gd" > artifacts/packed-reliable-actions.log 2>&1
rg -q RELIABLE_ACTIONS_RULES_PASS artifacts/packed-reliable-actions.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-reliable-actions.log; then cat artifacts/packed-reliable-actions.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/lag_compensation_rules.gd" > artifacts/packed-lag-compensation.log 2>&1
rg -q LAG_COMPENSATION_RULES_PASS artifacts/packed-lag-compensation.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-lag-compensation.log; then cat artifacts/packed-lag-compensation.log; exit 1; fi
timeout 35s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/navigation_rules.gd" > artifacts/packed-navigation.log 2>&1
rg -q NAVIGATION_RULES_PASS artifacts/packed-navigation.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked' artifacts/packed-navigation.log; then cat artifacts/packed-navigation.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless -- --smoke > artifacts/packed-smoke.log 2>&1
rg -q OFFLINE_SMOKE_PASS artifacts/packed-smoke.log
if rg -q "SCRIPT ERROR|Assertion failed" artifacts/packed-smoke.log; then cat artifacts/packed-smoke.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/grenade_rules.gd" > artifacts/packed-grenade.log 2>&1
rg -q GRENADE_RULES_PASS artifacts/packed-grenade.log
if rg -q "SCRIPT ERROR|Assertion failed" artifacts/packed-grenade.log; then cat artifacts/packed-grenade.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/prediction_rules.gd" > artifacts/packed-prediction.log 2>&1
rg -q PREDICTION_RULES_PASS artifacts/packed-prediction.log
if rg -q "SCRIPT ERROR|Assertion failed" artifacts/packed-prediction.log; then cat artifacts/packed-prediction.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/spectator_rules.gd" > artifacts/packed-spectator.log 2>&1
rg -q SPECTATOR_RULES_PASS artifacts/packed-spectator.log
if rg -q "SCRIPT ERROR|Assertion failed" artifacts/packed-spectator.log; then cat artifacts/packed-spectator.log; exit 1; fi
timeout 25s artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/viewmodel_rules.gd" > artifacts/packed-viewmodel.log 2>&1
rg -q VIEWMODEL_RULES_PASS artifacts/packed-viewmodel.log
if rg -q "SCRIPT ERROR|Assertion failed" artifacts/packed-viewmodel.log; then cat artifacts/packed-viewmodel.log; exit 1; fi
timeout 25s env AUDIO_ARTIFACT_DIR="$PWD/artifacts" artifacts/IronMeridian-Linux/play.sh --headless --script "$PWD/tests/audio_rules.gd" > artifacts/packed-audio.log 2>&1
rg -q AUDIO_RULES_PASS artifacts/packed-audio.log
if rg -q "SCRIPT ERROR|Assertion failed" artifacts/packed-audio.log; then cat artifacts/packed-audio.log; exit 1; fi
timeout 15s artifacts/IronMeridian-Linux/play.sh --headless --verbose --script "$PWD/tests/audio_shutdown.gd" > artifacts/packed-audio-shutdown.log 2>&1
rg -q AUDIO_SHUTDOWN_PENDING artifacts/packed-audio-shutdown.log
if rg -q 'SCRIPT ERROR|Assertion failed|ObjectDB instances leaked|still in use' artifacts/packed-audio-shutdown.log; then cat artifacts/packed-audio-shutdown.log; exit 1; fi
.venv/bin/python tools/test_local_profile.py --packed > artifacts/packed-local-profile.log 2>&1
tar -czf artifacts/IronMeridian-Linux-x86_64.tar.gz -C artifacts IronMeridian-Linux
