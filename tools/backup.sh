#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
backup_dir="artifacts/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
docker compose exec -T postgres pg_dump -U iron -d iron --format=custom > "$backup_dir/postgres.dump"
docker compose exec -T game sh -c 'if [ -f "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json" ]; then cat "/home/game/.local/share/godot/app_userdata/Iron Meridian/results.json"; else printf "[]"; fi' > "$backup_dir/results.json"
printf 'Backup saved: %s\n' "$backup_dir"
