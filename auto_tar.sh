#!/usr/bin/env bash
set -Eeuo pipefail

# deprecated, using borgmatic now

SOURCES=(
    "/mnt/tank0/appdata/immich-library"
    "/mnt/tank0/appdata/nextcloud"
    "/mnt/tank0/appdata/kavita-books"
    "/mnt/tank0/appdata/audiobookshelf"
    "/mnt/tank0/appdata/forgejo-app"
)

BACKUP_ROOT="/mnt/tank0/backup/auto-tar"

if [ ! -d "$BACKUP_ROOT" ]; then
    echo "Error: Backup directory not found: $BACKUP_ROOT" >&2
    exit 1
fi

for SRC in "${SOURCES[@]}"; do
    if [ ! -d "$SRC" ]; then
        echo "Error: Source directory not found: $SRC" >&2
        exit 1
    fi

    FOLDER_NAME=$(basename "$SRC")
    TIMESTAMP=$(date +%Y-%m-%d)
    ARCHIVE_PATH="$BACKUP_ROOT/${FOLDER_NAME}_${TIMESTAMP}.tar.gz"

    tar -uf "$ARCHIVE_PATH" -C "$PARENT_DIR" "$SRC" > /dev/null
    tar -Wf "$ARCHIVE_PATH" > /dev/null
done