#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/pool0/scripts"
REPO_DIR="${ROOT}/TrueNAS_helper_scripts/repo"
RELEASES="${ROOT}/TrueNAS_helper_scripts/releases"
CURRENT_LINK="${ROOT}/TrueNAS_helper_scripts/current"
LOG_DIR="${ROOT}/TrueNAS_helper_scripts/logs"
BRANCH="${BRANCH:-main}"
GIT_REMOTE_URL="git@github.com:alxan0/TrueNAS_Scale_helper_scripts.git"

# How many releases to keep (including the current one).
KEEP_COUNT="${KEEP_COUNT:-2}"

mkdir -p "$REPO_DIR" "$RELEASES" "$LOG_DIR"

# --- first-time clone ---
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone --depth=1 --branch "$BRANCH" "$GIT_REMOTE_URL" "$REPO_DIR"
fi

# --- update working tree ---
git -C "$REPO_DIR" fetch --prune --depth=1 --update-shallow origin "$BRANCH"
git -C "$REPO_DIR" checkout -q "$BRANCH"
git -C "$REPO_DIR" reset -q --hard "origin/$BRANCH"

COMMIT="$(git -C "$REPO_DIR" rev-parse --short HEAD)"
STAMP="$(date -u +'%Y-%m-%dT%H-%M-%S')"
TARGET="$RELEASES/$STAMP-$COMMIT"
mkdir -p "$TARGET"

rsync -a --delete --exclude ".git" "$REPO_DIR/" "$TARGET/"

ln -sfn "$TARGET" "$CURRENT_LINK"

echo "Deployed $COMMIT at $STAMP" | tee -a "$LOG_DIR/update.log"

# --- set permissions ---
sudo chmod -R 550 ${ROOT}/TrueNAS_helper_scripts

# --- retention policy ---
releases_sorted="$(find "$RELEASES" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -r)"
count=0
to_delete=()
IFS=$'\n'
for rel in $releases_sorted; do
  count=$((count + 1))
  if [ "$count" -gt "$KEEP_COUNT" ]; then
    to_delete+=("$RELEASES/$rel")
  fi
done
unset IFS

# Safety belt (normally $TARGET (the freshly deployed release) will never appear in $to_delete)
filtered=()
for d in "${to_delete[@]:-}"; do
  [ "$d" = "$TARGET" ] && continue
  filtered+=("$d")
done

if [ "${#filtered[@]}" -gt 0 ]; then
  printf 'Pruning %d old release(s):\n' "${#filtered[@]}"
  for d in "${filtered[@]}"; do
    echo "  - $d"
    rm -rf -- "$d"
  done
fi