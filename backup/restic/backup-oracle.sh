#!/bin/bash
# Exports the configured Oracle schema(s) with expdp (Data Pump — a
# consistent logical export, not a raw copy of datafiles mid-write, which
# can produce a corrupt backup on a database that's actually in use),
# then backs that dump up with restic.
set -euo pipefail
cd "$(dirname "$0")"
set -a
source .env
set +a
source lib.sh

: "${ORACLE_PASSWORD:?Set ORACLE_PASSWORD in .env}"
: "${ORACLE_BACKUP_SCHEMAS:?Set ORACLE_BACKUP_SCHEMAS in .env (your own app schema(s), not APEX_*)}"

PDB_NAME="${PDB_NAME:-FREEPDB1}"
DUMP_FILE="apex-$(date +%Y%m%d-%H%M%S).dmp"
LOG_FILE="${DUMP_FILE%.dmp}.log"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Writing this to a real file (rather than nesting heredocs inside
# `docker exec ... bash -c '...'`) sidesteps several layers of shell
# quoting that are easy to get subtly wrong.
cat > "${WORKDIR}/run-expdp.sh" <<INNERSCRIPT
#!/bin/bash
set -euo pipefail
mkdir -p /tmp/restic-backup
sqlplus -s / as sysdba <<SQL
whenever sqlerror exit failure
ALTER SESSION SET CONTAINER = ${PDB_NAME};
CREATE OR REPLACE DIRECTORY restic_backup_dir AS '/tmp/restic-backup';
exit
SQL
expdp userid=\"sys/${ORACLE_PASSWORD}@${PDB_NAME} as sysdba\" \\
  directory=restic_backup_dir \\
  dumpfile=${DUMP_FILE} \\
  logfile=${LOG_FILE} \\
  schemas=${ORACLE_BACKUP_SCHEMAS}
INNERSCRIPT

echo "Running expdp for schema(s) '${ORACLE_BACKUP_SCHEMAS}' inside ${APEX_DB_CONTAINER} ..."
docker cp "${WORKDIR}/run-expdp.sh" "${APEX_DB_CONTAINER}:/tmp/run-expdp.sh"
docker exec "${APEX_DB_CONTAINER}" bash /tmp/run-expdp.sh
# -u root: /tmp/run-expdp.sh was written by `docker cp`, so it's
# root-owned; /tmp has the sticky bit, so the container's default
# non-root user can't remove someone else's file there.
docker exec -u root "${APEX_DB_CONTAINER}" rm -f /tmp/run-expdp.sh

docker cp "${APEX_DB_CONTAINER}:/tmp/restic-backup/${DUMP_FILE}" "${WORKDIR}/${DUMP_FILE}"
docker exec "${APEX_DB_CONTAINER}" rm -f "/tmp/restic-backup/${DUMP_FILE}" "/tmp/restic-backup/${LOG_FILE}"

RESTIC_EXTRA_MOUNTS=("${WORKDIR}:/backup-source:ro")

ensure_repo

echo "Backing up with restic ..."
restic backup "/backup-source/${DUMP_FILE}" --tag oracle --host vps

echo "Pruning old snapshots ..."
restic forget --tag oracle --host vps \
  --keep-daily "${KEEP_DAILY}" --keep-weekly "${KEEP_WEEKLY}" --keep-monthly "${KEEP_MONTHLY}" --prune

echo "Oracle backup done."
