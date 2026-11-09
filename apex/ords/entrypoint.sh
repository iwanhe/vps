#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOSTNAME:=db}"
: "${DB_PORT:=1521}"
: "${DB_SERVICENAME:=FREEPDB1}"
: "${ORACLE_SYS_PASSWORD:?ORACLE_SYS_PASSWORD must be set}"

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
  echo "${ORACLE_SYS_PASSWORD}" | ords --config "${CONFIG_DIR}" install \
    --admin-user SYS \
    --db-hostname "${DB_HOSTNAME}" \
    --db-port "${DB_PORT}" \
    --db-servicename "${DB_SERVICENAME}" \
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
