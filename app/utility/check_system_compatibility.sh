#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="check_system_compatibility"
module_description="🛡️ chek system comptability"
group="hardening"
check_system_compatibility() {
    log "INFO" "Checking system compatibility..."

    # Check if running on Proxmox
    if ! command -v pveversion &>/dev/null; then
        log "ERROR" "This script is designed for Proxmox VE systems"
        exit 1
    fi
    echo -e "${GREEN}System compatibility check passed.${RESET}"
    # Check Proxmox version
    local pve_version=$(pveversion --verbose | head -1 | awk '{print $2}')
    log "INFO" "Detected Proxmox VE version: $pve_version"

    # Check available memory
    local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [[ $available_mem -lt 512 ]]; then
        log "WARN" "Low available memory: ${available_mem}MB. Some operations may fail."
    fi

    # Check disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then # 1GB in KB
        log "WARN" "Low disk space available. Consider freeing up space."
    fi
}
