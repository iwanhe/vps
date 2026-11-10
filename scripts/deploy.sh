#!/bin/bash
# Deploys every service in this repo that's actually configured. Run from
# the VPS itself (manually, or from .github/workflows/deploy.yml over SSH)
# after a `git pull`/`git reset --hard` to the commit you want live.
#
# One service failing to build/start doesn't stop the others — they're
# independent — but the script still exits non-zero overall if any did,
# so CI reflects it.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! ./scripts/create-edge-network.sh; then
  echo "Failed to create the edge network, aborting." >&2
  exit 1
fi

SERVICES=(
  "apps/nextjs"
  "apps/apex"
  "databases/postgres"
  "infrastructure/proxy/caddy"
)

FAILED=()

for svc in "${SERVICES[@]}"; do
  if [ ! -f "$svc/docker-compose.yml" ]; then
    echo "Skipping $svc (no docker-compose.yml)"
    continue
  fi
  if [ -f "$svc/.env.example" ] && [ ! -f "$svc/.env" ]; then
    echo "Skipping $svc (.env.example exists but .env hasn't been created yet — copy it and fill in real values first)"
    continue
  fi
  echo "Deploying $svc ..."
  if ! (cd "$svc" && docker compose up -d --build --remove-orphans); then
    echo "FAILED: $svc"
    FAILED+=("$svc")
  fi
done

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "Deploy finished with failures: ${FAILED[*]}"
  exit 1
fi

echo "Deploy finished, all configured services are up."
