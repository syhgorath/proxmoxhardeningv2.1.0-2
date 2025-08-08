#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="install_rkhunter"
module_description="🛡️ install rkhunter"
group="hardening"
version=1.0.0
install_rkhunter() {

    # Check if rkhunter is already installed
    if command -v rkhunter &>/dev/null; then
        echo "rkhunter is already installed."
        return 0
    fi

    # Install rkhunter
    # Check if rkhunter is installed
    if ! command -v rkhunter &>/dev/null; then
        echo "Installing rkhunter..."
        apt-get update && apt-get install -y rkhunter || {
            echo "Failed to install rkhunter"
            return 1
        }
    else
        echo "rkhunter is already installed."
    fi
    run_rkhunter_check

    # Configure rkhunter
    RKHUNTERCONF="/etc/default/rkhunter.conf"
    grep -q '^CRON_DAILY_RUN=' "$RKHUNTERCONF" || echo 'CRON_DAILY_RUN="yes"' >>"$RKHUNTERCONF"
    grep -q '^APT_AUTOGEN=' "$RKHUNTERCONF" || echo 'APT_AUTOGEN="yes"' >>"$RKHUNTERCONF"

}
