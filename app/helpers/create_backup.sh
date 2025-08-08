#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
# Backup with versioning
create_backup() {
    local file="$1"
    local backup_name="$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"

    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/$backup_name"
        log "INFO" "Backup created: $backup_name"
    else
        log "WARN" "File not found for backup: $file"
    fi
}