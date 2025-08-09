#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
CheckRoot() {
    if [[ "${DRY_RUN:-}" == "1" || "${DRY_RUN:-}" == "true" ]]; then
        echo -e "${YELLOW}Dry-run mode: skipping root privilege check${RESET}"
        return 0
    fi
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${RESET}" >&2
        exit 1
    fi
}
