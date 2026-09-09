#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose ps
curl --fail --silent --show-error http://127.0.0.1:8000/health
printf '\n'
docker compose logs --tail 15 game
