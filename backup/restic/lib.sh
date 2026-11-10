# Shared by every script in this folder. Source it after `source .env`.

# Runs restic inside its official container. Set RESTIC_EXTRA_MOUNTS (a
# bash array of "host:container[:ro]" strings) before calling this if the
# command needs something mounted in besides the repository itself, e.g.:
#   RESTIC_EXTRA_MOUNTS=("$DUMP_DIR:/backup-source:ro")
#   restic backup /backup-source
restic() {
  local args=(--rm -e RESTIC_REPOSITORY="${RESTIC_REPOSITORY}" -e RESTIC_PASSWORD="${RESTIC_PASSWORD}")
  if [[ "${RESTIC_REPOSITORY}" == /* ]]; then
    mkdir -p "${RESTIC_REPOSITORY}"
    args+=(-v "${RESTIC_REPOSITORY}:${RESTIC_REPOSITORY}")
  fi
  local mount
  for mount in "${RESTIC_EXTRA_MOUNTS[@]:-}"; do
    [ -n "$mount" ] && args+=(-v "$mount")
  done
  docker run "${args[@]}" restic/restic:latest "$@"
}

ensure_repo() {
  if ! restic snapshots >/dev/null 2>&1; then
    echo "Repository not initialized yet, running 'restic init' ..."
    restic init
  fi
}
