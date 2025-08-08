#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local color=""

    case "$level" in
    "INFO") color="$GREEN" ;;
    "WARN") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
    "DEBUG") color="$BLUE" ;;
    *) color="$NC" ;;
    esac
 
    echo -e "${color}[$timestamp] [$level] $message${RESET}"
    echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
    logger -t "proxmox-hardening-v2" "[$level] $message"
}