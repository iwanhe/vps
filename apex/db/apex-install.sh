#!/bin/bash
# Runs once, automatically, on the container's first startup (dropped into
# /container-entrypoint-initdb.d by the Dockerfile). Installs the Oracle APEX
# engine into the PDB and sets the workspace INTERNAL admin password.
set -euo pipefail

PDB_NAME="${PDB_NAME:-FREEPDB1}"
ADMIN_EMAIL="${APEX_ADMIN_EMAIL:-admin@example.com}"

if [ -z "${APEX_ADMIN_PASSWORD:-}" ]; then
  echo "CONTAINER: APEX_ADMIN_PASSWORD is not set, refusing to install APEX without an admin password." >&2
  exit 1
fi

echo "CONTAINER: Installing Oracle APEX into PDB ${PDB_NAME} (this takes a while) ..."
sqlplus -s / as sysdba <<SQL
whenever sqlerror exit failure
ALTER SESSION SET CONTAINER = ${PDB_NAME};
@/opt/apex/apexins.sql SYSAUX SYSAUX TEMP /i/
exit
SQL

echo "CONTAINER: Setting the APEX workspace admin (ADMIN) password ..."
sqlplus -s / as sysdba <<SQL
whenever sqlerror exit failure
ALTER SESSION SET CONTAINER = ${PDB_NAME};
@/opt/apex/apxchpwd.sql
ADMIN
${ADMIN_EMAIL}
${APEX_ADMIN_PASSWORD}
exit
SQL

echo "CONTAINER: Oracle APEX install complete."
