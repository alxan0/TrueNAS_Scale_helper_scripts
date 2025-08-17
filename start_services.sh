#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/mnt/pool0/appdata/dockge/stacks"

# === EDIT THIS ORDER ===
# Put only the stack folder names you want to manage, in dependency-safe start order.
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

# Ensure compose is callable
if ! command -v docker &>/dev/null; then
  die "docker not found in PATH"
fi

have_wait=0
if $COMPOSE_BIN up -h 2>&1 | grep -q -- "--wait"; then
  have_wait=1
fi

find_compose_file() {
  local dir="$1"
  if [[ -f "${dir}/compose.yaml" ]]; then
    printf '%s' "${dir}/compose.yaml"
  elif [[ -f "${dir}/docker-compose.yml" ]]; then
    printf '%s' "${dir}/docker-compose.yml"
  else
    return 1
  fi
}

start_stack() {
  local name="$1"
  local dir="${ROOT}/${name}"
  [[ -d "$dir" ]] || die "Stack folder not found: ${name}"

  local file
  file="$(find_compose_file "$dir")" || die "No compose file in ${dir} (expected compose.yaml or docker-compose.yml)"

  log "Stopping & removing old containers for '${name}' using ${file} ..."

  # Build 'down' args based on toggles
  local down_args=( -f "$file" down --remove-orphans )
  # if [[ "${PURGE_VOLUMES:-0}" == "1" ]]; then
  #   down_args+=( --volumes )
  # fi
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
  log "Started '${name}'."
}

stop_stack() {
  local name="$1"
  local dir="${ROOT}/${name}"
  [[ -d "$dir" ]] || die "Stack folder not found: ${name}"

  local file
  file="$(find_compose_file "$dir")" || die "No compose file in ${dir} (expected compose.yaml or docker-compose.yml)"

  log "Stopping '${name}' using ${file} ..."

  local down_args=( -f "$file" down --remove-orphans )
  # if [[ "${PURGE_VOLUMES:-0}" == "1" ]]; then
  #   down_args+=( --volumes )
  # fi
  if [[ "${PURGE_IMAGES:-0}" == "1" ]]; then
    down_args+=( --rmi local )
  fi

  $COMPOSE_BIN "${down_args[@]}"
  log "Stopped '${name}'."
}

do_nextcloud_cycle() {
  # Start/stop orchestration for Nextcloud AIO mastercontainer
  # Only run during 'start' or 'restart'
  if command -v sudo &>/dev/null; then
    sudo docker exec --env DAILY_BACKUP=0 --env STOP_CONTAINERS=1  nextcloud-aio-mastercontainer /daily-backup.sh || log "nextcloud stop hook failed (continuing)"
    sudo docker exec --env DAILY_BACKUP=0 --env START_CONTAINERS=1 nextcloud-aio-mastercontainer /daily-backup.sh || log "nextcloud start hook failed (continuing)"
  else
    docker exec --env DAILY_BACKUP=0 --env STOP_CONTAINERS=1  nextcloud-aio-mastercontainer /daily-backup.sh || log "nextcloud stop hook failed (continuing)"
    docker exec --env DAILY_BACKUP=0 --env START_CONTAINERS=1 nextcloud-aio-mastercontainer /daily-backup.sh || log "nextcloud start hook failed (continuing)"
  fi
}


usage() {
  cat <<'EOF'
Usage:
  script.sh start        [--dry-run]   # start all stacks in ORDER (default cmd)
  script.sh stop         [--dry-run]   # stop all stacks in reverse ORDER
  script.sh restart      [--dry-run]   # stop (reverse) then start (forward)
  script.sh list                        # print stack order
Environment toggles:
  PURGE_VOLUMES=1  # include '--volumes' on down
  PURGE_IMAGES=1   # include '--rmi local' on down
Notes:
  - 'stop' and the stop phase of 'restart' happen in reverse ORDER to respect dependencies.
  - Nextcloud AIO hooks and GPU undervolt run only on 'start' and 'restart'.
EOF
}

main() {
  local cmd="${1:-start}"
  local dry=0
  if [[ "${2:-}" == "--dry-run" || "${1:-}" == "--dry-run" ]]; then
    dry=1
    # normalize: if first arg was --dry-run, default to 'start'
    [[ "${1:-}" == "--dry-run" ]] && cmd="start"
  fi

  case "$cmd" in
    list)
      log "Stack order:"
      printf '  - %s\n' "${ORDER[@]}"
      ;;
    start)
      if (( dry )); then
        log "Dry run. Would START in order:"
        printf '  - %s\n' "${ORDER[@]}"
        exit 0
      fi
      for s in "${ORDER[@]}"; do
        start_stack "$s"
      done
      do_nextcloud_cycle
      log "All requested stacks started successfully."
      ;;
    stop)
      if (( dry )); then
        log "Dry run. Would STOP in reverse order:"
        for (( i=${#ORDER[@]}-1; i>=0; i-- )); do printf '  - %s\n' "${ORDER[i]}"; done
        exit 0
      fi
      for (( i=${#ORDER[@]}-1; i>=0; i-- )); do
        stop_stack "${ORDER[i]}"
      done
      sudo docker exec --env DAILY_BACKUP=0 --env STOP_CONTAINERS=1  nextcloud-aio-mastercontainer /daily-backup.sh || log "nextcloud stop hook failed (continuing)"
      log "All requested stacks stopped successfully."
      ;;
    restart)
      if (( dry )); then
        log "Dry run. Would STOP in reverse order, then START in order:"
        for (( i=${#ORDER[@]}-1; i>=0; i-- )); do printf '  - %s\n' "${ORDER[i]}"; done
        printf '  -- then --\n'
        printf '  - %s\n' "${ORDER[@]}"
        exit 0
      fi
      # stop reverse
      for (( i=${#ORDER[@]}-1; i>=0; i-- )); do
        stop_stack "${ORDER[i]}"
      done
      # start forward
      for s in "${ORDER[@]}"; do
        start_stack "$s"
      done
      do_nextcloud_cycle
      log "All requested stacks restarted successfully."
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
