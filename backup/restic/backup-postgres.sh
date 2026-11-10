#!/bin/bash
# Dumps the Postgres database with pg_dump (a consistent, logical dump —
# not a raw copy of the data directory while it's being written to), then
# backs that dump up with restic.
set -euo pipefail
cd "$(dirname "$0")"
set -a
source .env
set +a
source lib.sh

DUMP_DIR="$(mktemp -d)"
trap 'rm -rf "$DUMP_DIR"' EXIT
chmod 755 "$DUMP_DIR"

echo "Dumping Postgres database '${POSTGRES_DB}' ..."
docker exec "${POSTGRES_CONTAINER}" pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -Fc \
  > "${DUMP_DIR}/postgres-${POSTGRES_DB}.dump"

RESTIC_EXTRA_MOUNTS=("${DUMP_DIR}:/backup-source:ro")

ensure_repo

echo "Backing up with restic ..."
restic backup /backup-source --tag postgres --host vps

echo "Pruning old snapshots ..."
restic forget --tag postgres --host vps \
  --keep-daily "${KEEP_DAILY}" --keep-weekly "${KEEP_WEEKLY}" --keep-monthly "${KEEP_MONTHLY}" --prune

echo "Postgres backup done."
