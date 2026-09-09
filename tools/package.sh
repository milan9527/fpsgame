#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts/IronMeridian-Linux
./tools/godot --headless --path client --export-pack Linux ../artifacts/IronMeridian-Linux/IronMeridian.pck
cp tools/godot artifacts/IronMeridian-Linux/IronMeridian
cp docs/PLAYER_GUIDE.md artifacts/IronMeridian-Linux/PLAYER_GUIDE.md
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
tar -czf artifacts/IronMeridian-Linux-x86_64.tar.gz -C artifacts IronMeridian-Linux
