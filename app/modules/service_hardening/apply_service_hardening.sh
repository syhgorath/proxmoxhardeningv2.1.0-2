#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="apply_service_hardening"
module_description="🛡️ apply service hardening"
version=1.0.0
group="hardening"

apply_service_hardening() {
    log "INFO" "Applying advanced service hardening..."

    # Disable unnecessary services
    local services_to_disable=(
        "avahi-daemon" "cups" "bluetooth" "ModemManager"
        "whoopsie" "apport" "snapd" "accounts-daemon"
        "packagekit" "udisks2" "colord" "geoclue"
    )

    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            log "INFO" "Disabled service: $service"
        fi
    done

    # Configure AppArmor
    if ! systemctl is-active --quiet apparmor; then
        apt update && apt install apparmor apparmor-profiles apparmor-profiles-extra apparmor-utils -y
        systemctl enable apparmor
        systemctl start apparmor
    fi

    # Enforce all AppArmor profiles
    find /etc/apparmor.d/ -maxdepth 1 -type f -name "*" -exec aa-enforce {} \; 2>/dev/null || true

    # Create custom AppArmor profile for Proxmox services
    cat >/etc/apparmor.d/local/pveproxy <<'EOF'
# Local customizations for pveproxy
/var/log/pveproxy/ rw,
/var/log/pveproxy/** rw,
/etc/pve/ r,
/etc/pve/** r,
EOF

    service_contents

    # Reload systemd
    systemctl daemon-reexec
    systemctl daemon-reload

    # Configure shared memory security
    if ! grep -q "tmpfs.*shm.*noexec" /etc/fstab; then
        echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev,size=512M 0 0" >>/etc/fstab
    fi

    log "INFO" "Service hardening applied"
}
