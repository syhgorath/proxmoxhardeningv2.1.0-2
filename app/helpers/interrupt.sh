#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
interrupt() {
    echo -e "\n${YELLOW}Script interrupted. Cleaning up...${RESET}"
    # Remove any temporary files
    rm -f /tmp/current_suid_sgid /tmp/moduli.candidates
    exit 1
}