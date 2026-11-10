#!/bin/bash
# Restores the latest (or a given) restic Oracle snapshot with impdp.
# Imports with TABLE_EXISTS_ACTION=REPLACE, so existing objects in the
# target schema(s) get overwritten — confirm ORACLE_BACKUP_SCHEMAS in
# .env is really what you mean before running this.
#
# Usage: ./restore-oracle.sh [snapshot-id]   (default: latest)
set -euo pipefail
cd "$(dirname "$0")"
set -a
source .env
set +a
source lib.sh

: "${ORACLE_PASSWORD:?Set ORACLE_PASSWORD in .env}"
: "${ORACLE_BACKUP_SCHEMAS:?Set ORACLE_BACKUP_SCHEMAS in .env}"

PDB_NAME="${PDB_NAME:-FREEPDB1}"
SNAPSHOT="${1:-latest}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
chmod 755 "$WORKDIR"

RESTIC_EXTRA_MOUNTS=("${WORKDIR}:/restore-target")

echo "Restoring snapshot '${SNAPSHOT}' (tag oracle) to a temp dir ..."
restic restore "${SNAPSHOT}" --tag oracle --host vps --target /restore-target

DUMP_FILE=$(find "${WORKDIR}" -name '*.dmp' | head -1)
if [ -z "${DUMP_FILE}" ]; then
  echo "No .dmp file found in the restored snapshot." >&2
  exit 1
fi
DUMP_BASENAME="$(basename "${DUMP_FILE}")"

cat > "${WORKDIR}/run-impdp.sh" <<INNERSCRIPT
#!/bin/bash
set -euo pipefail
mkdir -p /tmp/restic-restore
sqlplus -s / as sysdba <<SQL
whenever sqlerror exit failure
ALTER SESSION SET CONTAINER = ${PDB_NAME};
CREATE OR REPLACE DIRECTORY restic_restore_dir AS '/tmp/restic-restore';
exit
SQL
set +e
impdp userid=\"sys/${ORACLE_PASSWORD}@${PDB_NAME} as sysdba\" \\
  directory=restic_restore_dir \\
  dumpfile=${DUMP_BASENAME} \\
  schemas=${ORACLE_BACKUP_SCHEMAS} \\
  table_exists_action=replace
rc=\$?
set -e
# impdp exits 5 for "completed with warnings" — e.g. the target schema
# (as opposed to its tables/data) already existed, which is expected and
# harmless when restoring into a schema that's still there. Anything
# else is a real failure.
if [ "\$rc" != "0" ] && [ "\$rc" != "5" ]; then
  exit "\$rc"
fi
INNERSCRIPT

docker exec "${APEX_DB_CONTAINER}" mkdir -p /tmp/restic-restore
docker cp "${DUMP_FILE}" "${APEX_DB_CONTAINER}:/tmp/restic-restore/${DUMP_BASENAME}"
docker cp "${WORKDIR}/run-impdp.sh" "${APEX_DB_CONTAINER}:/tmp/run-impdp.sh"
# docker cp always writes as root; the container runs the DB (and impdp)
# as a non-root user, which otherwise can't read what was just copied in.
docker exec -u root "${APEX_DB_CONTAINER}" chmod 644 "/tmp/restic-restore/${DUMP_BASENAME}" /tmp/run-impdp.sh

echo "Running impdp inside ${APEX_DB_CONTAINER} ..."
docker exec "${APEX_DB_CONTAINER}" bash /tmp/run-impdp.sh

# -u root: /tmp/run-impdp.sh was written by `docker cp`, so it's
# root-owned; /tmp has the sticky bit, so the container's default
# non-root user can't remove someone else's file there.
docker exec -u root "${APEX_DB_CONTAINER}" rm -rf /tmp/run-impdp.sh /tmp/restic-restore

echo "Oracle restore done."
