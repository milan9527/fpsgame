#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts/IronMeridian-Linux
./tools/godot --headless --path client --export-pack Linux ../artifacts/IronMeridian-Linux/IronMeridian.pck
cp tools/godot artifacts/IronMeridian-Linux/IronMeridian
cp docs/PLAYER_GUIDE.md artifacts/IronMeridian-Linux/PLAYER_GUIDE.md
mkdir -p artifacts/IronMeridian-Linux/docs
cp docs/LOCAL_RESULTS.md artifacts/IronMeridian-Linux/docs/LOCAL_RESULTS.md
cp LICENSE artifacts/IronMeridian-Linux/LICENSE
cat > artifacts/IronMeridian-Linux/play.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec ./IronMeridian --main-pack IronMeridian.pck "$@"
SH
chmod +x artifacts/IronMeridian-Linux/play.sh
# A packed-project smoke run checks imported GLB assets and resource paths.
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
