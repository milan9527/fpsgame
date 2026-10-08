#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
state_dir="$project_dir/artifacts/background-goal"
mkdir -p "$state_dir"
exec 9>"$state_dir/worker.lock"
flock -n 9 || exit 0
[[ -f "$state_dir/completed" ]] && exit 0
export PATH="/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin"
echo "$$" > "$state_dir/worker.pid"
trap 'rm -f "$state_dir/worker.pid"' EXIT
while true; do
  round="$(date -u +%Y%m%dT%H%M%SZ)"
  echo "$round running" > "$state_dir/status"
  if timeout --signal=TERM --kill-after=60s 90m codex exec -C "$project_dir" --sandbox danger-full-access \
    -c approval_policy='"never"' \
    -c model_auto_compact_token_limit=32000 \
    -c tool_output_token_limit=4000 \
    --output-schema "$project_dir/tools/background_goal_schema.json" \
    -o "$state_dir/$round-result.json" \
    - < "$project_dir/docs/BACKGROUND_GOAL.md" \
    > "$state_dir/$round.log" 2>&1; then
    if python3 - "$state_dir/$round-result.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    result = json.load(f)
sys.exit(0 if result.get("status") == "complete" and result.get("evidence") else 1)
PY
    then
      if python3 "$project_dir/tools/check_android_acceptance.py" \
        > "$state_dir/$round-acceptance-check.json" 2>&1; then
        echo "$round complete; see $round-result.json" > "$state_dir/status"
        touch "$state_dir/completed"
        exit 0
      fi
      echo "$round completion rejected: Android evidence gate failed" >> "$state_dir/events.log"
    fi
    echo "$round checkpoint saved; next round in 30 seconds" > "$state_dir/status"
    sleep 30
  else
    echo "$round invocation failed; retry in 300 seconds; see $round.log" > "$state_dir/status"
    sleep 300
  fi
done
