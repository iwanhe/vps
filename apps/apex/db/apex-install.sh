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

if [ -z "${APEX_PUBLIC_USER_PASSWORD:-}" ]; then
  echo "CONTAINER: APEX_PUBLIC_USER_PASSWORD is not set, refusing to install APEX without it." >&2
  exit 1
fi

# cd + relative paths matters here: when @ is fed through stdin (as below)
# rather than given to sqlplus as a command-line argument, nested @@
# includes inside apexins.sql/apxchpwd.sql resolve against the process's
# CWD, not the path given to the top-level @ — an absolute path breaks
# every @@ inside the script with "SP2-0310: unable to open file" (confirmed
# by testing both ways).
cd /opt/apex

echo "CONTAINER: Installing Oracle APEX into PDB ${PDB_NAME} (this takes a while) ..."
sqlplus -s / as sysdba <<SQL
whenever sqlerror exit failure
ALTER SESSION SET CONTAINER = ${PDB_NAME};
@apexins.sql SYSAUX SYSAUX TEMP /i/
exit
SQL

echo "CONTAINER: Setting the APEX workspace admin (ADMIN) password ..."
# Not using apxchpwd.sql directly: its ACCEPT ... HIDE prompts don't read
# correctly when stdin isn't a real TTY (confirmed by testing — it always
# reports "ORA-20001: Invalid password" no matter the password supplied,
# even though the same underlying API call below works fine). Call the
# same API it calls, directly, instead.
ESCAPED_PASSWORD="${APEX_ADMIN_PASSWORD//\'/\'\'}"
ESCAPED_EMAIL="${ADMIN_EMAIL//\'/\'\'}"
sqlplus -s / as sysdba <<SQL
whenever sqlerror exit failure
ALTER SESSION SET CONTAINER = ${PDB_NAME};
@@core/scripts/set_appun.sql
ALTER SESSION SET CURRENT_SCHEMA = &APPUN;
SET DEFINE OFF
BEGIN
  wwv_flow_instance_admin.create_or_update_admin_user(
    p_username => 'ADMIN',
    p_email    => '${ESCAPED_EMAIL}',
    p_password => '${ESCAPED_PASSWORD}' );
  COMMIT;
END;
/
exit
SQL

echo "CONTAINER: Setting the APEX_PUBLIC_USER password (needed by ORDS's PL/SQL gateway, 'direct' mode) ..."
# apexins.sql gives APEX_PUBLIC_USER a random password with no way to
# retrieve it, but ORDS's gateway-mode=direct connects AS this user with
# an actual password (confirmed by testing: `ords install --gateway-user
# APEX_PUBLIC_USER` fails with ORA-01017 unless this user's password is
# a known value matching what's fed to ords install on the other side).
sqlplus -s / as sysdba <<SQL
whenever sqlerror exit failure
ALTER SESSION SET CONTAINER = ${PDB_NAME};
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "${APEX_PUBLIC_USER_PASSWORD}";
exit
SQL

echo "CONTAINER: Oracle APEX install complete."
