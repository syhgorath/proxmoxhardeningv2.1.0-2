#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${RESET}" >&2
        exit 1
    fi
}