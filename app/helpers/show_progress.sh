#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
show_progress() {
    local step="$1"
    local current="$2"
    local total="$3"
    local percentage=$((current * 100 / total))

    printf "\r${CYAN}[%d/%d] (%d%%) %s${RESET}" "$current" "$total" "$percentage" "$step"
    echo "$current/$total" >"$PROGRESS_FILE"
}