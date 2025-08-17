#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/mnt/pool0/appdata/dockge/stacks"

# === EDIT THIS ORDER ===
# Put only the stack folder names you want to start, in the order you want.
ORDER=(
  socket-proxy
  traefik
  frigate-main
  qbittorrent
  gopeed
  jellyfin
  kavita
  nextcloud-aio
  forgejo
  immich
  homepage
)

# === CONFIG ===
COMPOSE_BIN="${COMPOSE_BIN:-/usr/bin/docker compose}"

log() { printf "[%(%F %T)T] %s\n" -1 "$*"; }
die() { log "ERROR: $*"; exit 1; }

have_wait=0
if $COMPOSE_BIN up -h 2>&1 | grep -q -- "--wait"; then
  have_wait=1
fi

start_stack() {
  local name="$1"
  local dir="${ROOT}/${name}"
  local file=""
  [[ -d "$dir" ]] || die "Stack folder not found: ${name}"

  if [[ -f "${dir}/compose.yaml" ]]; then
    file="${dir}/compose.yaml"
  elif [[ -f "${dir}/docker-compose.yml" ]]; then
    file="${dir}/docker-compose.yml"
  else
    die "No compose file in ${dir} (expected compose.yaml or docker-compose.yml)"
  fi

  log "Stopping & removing old containers for '${name}' using ${file} ..."

  # Build 'down' args based on toggles
  local down_args=( -f "$file" down --remove-orphans )
  if [[ "${PURGE_VOLUMES:-0}" == "1" ]]; then
    down_args+=( --volumes )
  fi
  if [[ "${PURGE_IMAGES:-0}" == "1" ]]; then
    # remove images that have no custom name (safe-ish); use '--rmi all' to be more aggressive
    down_args+=( --rmi local )
  fi

  # Compose DOWN
  $COMPOSE_BIN "${down_args[@]}"

  log "Starting '${name}' ..."
  if (( have_wait )); then
    $COMPOSE_BIN -f "$file" up -d --remove-orphans --wait
  else
    $COMPOSE_BIN -f "$file" up -d --remove-orphans
  fi
  log "Restarted '${name}'."
}

main() {
  # Dry-run
  if [[ "${1:-}" == "--dry-run" ]]; then
    log "Dry run. Would start in order:"
    printf '  - %s\n' "${ORDER[@]}"
    exit 0
  fi

  for s in "${ORDER[@]}"; do
    start_stack "$s"
  done

  sudo docker exec --env DAILY_BACKUP=0 --env STOP_CONTAINERS=1 nextcloud-aio-mastercontainer /daily-backup.sh
  sudo docker exec --env DAILY_BACKUP=0 --env START_CONTAINERS=1 nextcloud-aio-mastercontainer /daily-backup.sh

  python /mnt/pool0/scripts/undervolt.py --gpu -85

  log "All requested stacks started successfully."
}

main "$@"
