#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose ps
api_address="$(docker compose port api 8000)"
curl --fail --silent --show-error "http://${api_address}/health"
printf '\n'
docker compose logs --tail 15 game
