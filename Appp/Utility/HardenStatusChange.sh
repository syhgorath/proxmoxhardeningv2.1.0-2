#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="HardenStatusChange"
module_description="🛡️ harden status change"
version=1.0.0
menu_name=$module_name
menu_description=$module_description
HardenStatusChange() {

    HARDEN_FILE="/etc/systemd/system/ssh.service.d/hardening.conf"
    DISABLED_FILE="/etc/systemd/system/ssh.service.d/hardening.conf.disabled"

    if [ -f "$HARDEN_FILE" ]; then
        echo "[INFO] Disabling SSH hardening temporarily..."
        mv "$HARDEN_FILE" "$DISABLED_FILE"
        systemctl daemon-reload
        systemctl restart sshd
        echo "[INFO] SSH hardening disabled."
    elif [ -f "$DISABLED_FILE" ]; then
        echo "[INFO] Re-enabling SSH hardening..."
        mv "$DISABLED_FILE" "$HARDEN_FILE"
        systemctl daemon-reload
        systemctl restart sshd
        echo "[INFO] SSH hardening re-enabled."
    else
        echo "[ERROR] Neither hardening.conf nor .disabled found!"
        exit 1
    fi
}
