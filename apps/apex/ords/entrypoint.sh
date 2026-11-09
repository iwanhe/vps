#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOSTNAME:=db}"
: "${DB_PORT:=1521}"
: "${DB_SERVICENAME:=FREEPDB1}"
: "${ORACLE_SYS_PASSWORD:?ORACLE_SYS_PASSWORD must be set}"
: "${APEX_PUBLIC_USER_PASSWORD:?APEX_PUBLIC_USER_PASSWORD must be set}"
: "${ORDS_PUBLIC_USER_PASSWORD:?ORDS_PUBLIC_USER_PASSWORD must be set}"

CONFIG_DIR="/etc/ords/config"
INSTALLED_MARKER="${CONFIG_DIR}/.ords-installed"

mkdir -p "${CONFIG_DIR}"

wait_for_db() {
  echo "Waiting for ${DB_HOSTNAME}:${DB_PORT}/${DB_SERVICENAME} to accept connections ..."
  for _ in $(seq 1 60); do
    if (exec 3<>"/dev/tcp/${DB_HOSTNAME}/${DB_PORT}") 2>/dev/null; then
      exec 3>&- 3<&-
      echo "Database is reachable."
      return 0
    fi
    sleep 5
  done
  echo "Timed out waiting for the database." >&2
  exit 1
}

install_ords() {
  echo "Installing the ORDS schema and database connection pool ..."
  # Found by testing against a live DB (both a fresh one and a half-installed
  # one), not just --help text:
  # - --gateway-mode direct connects to the DB AS APEX_PUBLIC_USER with a
  #   real password, so that user needs one (ORA-01017 otherwise — this is
  #   the one apex-install.sh sets in the db container).
  # - Without --proxy-user, install fails with "Missing the ORDS_PUBLIC_USER
  #   password that is required to store in the configuration" even on a
  #   fresh schema (not just on reinstall) — --proxy-user is required, not
  #   optional, whenever --password-stdin is used.
  # - With --proxy-user present, --password-stdin reads lines in this exact
  #   order: admin (SYS), then proxy-user (ORDS_PUBLIC_USER), then
  #   gateway-user (APEX_PUBLIC_USER) — not the order the flags are listed
  #   on the command line.
  printf '%s\n%s\n%s\n' \
    "${ORACLE_SYS_PASSWORD}" "${ORDS_PUBLIC_USER_PASSWORD}" "${APEX_PUBLIC_USER_PASSWORD}" \
    | ords --config "${CONFIG_DIR}" install \
      --admin-user SYS \
      --db-hostname "${DB_HOSTNAME}" \
      --db-port "${DB_PORT}" \
      --db-servicename "${DB_SERVICENAME}" \
      --proxy-user \
      --gateway-mode direct \
      --gateway-user APEX_PUBLIC_USER \
      --feature-db-api true \
      --feature-rest-enabled-sql true \
      --feature-sdw true \
      --password-stdin
  touch "${INSTALLED_MARKER}"
}

wait_for_db

if [ ! -f "${INSTALLED_MARKER}" ]; then
  install_ords
else
  echo "ORDS already installed against ${CONFIG_DIR}, skipping install."
fi

exec ords --config "${CONFIG_DIR}" serve --apex-images /opt/apex/images
