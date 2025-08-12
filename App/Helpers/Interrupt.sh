#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="Hardeners"
module_name="Interrupt"
module_description="Handles script interruption and cleanup."
version=1.0.0
Interrupt() {
    echo -e "\n${YELLOW}Script interrupted. Cleaning up...${RESET}"
    # Remove any temporary files
    rm -f /tmp/current_suid_sgid /tmp/moduli.candidates
    exit 1
}
