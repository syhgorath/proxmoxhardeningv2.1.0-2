#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="ShowProgress"
module_description="ShowProgress function to display progress in the terminal."
version=1.0.0
ShowProgress() {
    local step="$1"
    local current="$2"
    local total="$3"
    local percentage=$((current * 100 / total))

    printf "\r${CYAN}[%d/%d] (%d%%) %s${RESET}" "$current" "$total" "$percentage" "$step"
    echo "$current/$total" >"$PROGRESS_FILE"
}
