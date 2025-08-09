#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="SetupAutomatedUpdates"
module_description="🛡️ setup automated updates"
version=1.0.0
group="hardening"
 #Function to setup automated security updates
SetupAutomatedUpdates() {
    Log "INFO" "Setting up automated security updates..."

    if ! dpkg -l unattended-upgrades &>/dev/null; then
        apt update && apt install unattended-upgrades -y
    fi

    cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
// Enhanced Unattended Upgrades Configuration
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
    "Proxmox:${distro_codename}";
};

// Package blacklist
Unattended-Upgrade::Package-Blacklist {
    "kernel*";
    "proxmox-ve";
    "pve-kernel-*";
};

// Automatic cleanup
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";

// Logging
Unattended-Upgrade::SysLogEnable "true";
Unattended-Upgrade::SysLogFacility "daemon";

// Email notifications
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
EOF

    cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades

    Log "INFO" "Automated security updates configured"
}
