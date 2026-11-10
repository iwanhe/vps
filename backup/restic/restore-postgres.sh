#!/bin/bash
# Restores the latest (or a given) restic snapshot into the running
# Postgres container. This DROPS AND RECREATES the target database —
# confirm POSTGRES_DB in .env is really the one you mean before running
# this against anything that matters.
#
# Usage: ./restore-postgres.sh [snapshot-id]   (default: latest)
set -euo pipefail
cd "$(dirname "$0")"
set -a
source .env
set +a
source lib.sh

SNAPSHOT="${1:-latest}"
RESTORE_DIR="$(mktemp -d)"
trap 'rm -rf "$RESTORE_DIR"' EXIT
chmod 755 "$RESTORE_DIR"

RESTIC_EXTRA_MOUNTS=("${RESTORE_DIR}:/restore-target")

echo "Restoring snapshot '${SNAPSHOT}' (tag postgres) to a temp dir ..."
restic restore "${SNAPSHOT}" --tag postgres --host vps --target /restore-target

DUMP_FILE=$(find "${RESTORE_DIR}" -name '*.dump' | head -1)
if [ -z "${DUMP_FILE}" ]; then
  echo "No .dump file found in the restored snapshot." >&2
  exit 1
fi

echo "Found dump: ${DUMP_FILE}"
echo "Recreating database '${POSTGRES_DB}' ..."
docker exec "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" -d postgres \
  -c "DROP DATABASE IF EXISTS \"${POSTGRES_DB}\";" \
  -c "CREATE DATABASE \"${POSTGRES_DB}\" OWNER \"${POSTGRES_USER}\";"

echo "Restoring the dump ..."
docker cp "${DUMP_FILE}" "${POSTGRES_CONTAINER}:/tmp/restore.dump"
docker exec "${POSTGRES_CONTAINER}" pg_restore -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" /tmp/restore.dump
docker exec "${POSTGRES_CONTAINER}" rm -f /tmp/restore.dump

echo "Postgres restore done."
