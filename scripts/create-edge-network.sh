#!/bin/bash
# Run once on the VPS before starting any service that's meant to be
# reachable through Caddy's reverse proxy (WP3). Every such service's
# docker-compose.yml joins this network as external — it has to exist
# before `docker compose up` on any of them, or that will fail.
set -euo pipefail

if docker network inspect edge >/dev/null 2>&1; then
  echo "Network 'edge' already exists."
else
  docker network create edge
  echo "Created network 'edge'."
fi
