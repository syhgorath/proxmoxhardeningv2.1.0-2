#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="hardening"
module_name="ConfigureFileSystemSecurity"
module_description="🛡️ configure filesystem security"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"

ConfigureFileSystemSecurity() {
    Log "INFO" "Configuring filesystem security..."

    CreateBackup "/etc/fstab"

    # Configure secure mount options for tmpfs
    if ! grep -q "tmpfs.*tmp.*nosuid" /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,nosuid,nodev,noexec,size=2G 0 0" >>/etc/fstab
    fi

    if ! grep -q "tmpfs.*shm.*nosuid" /etc/fstab; then
        echo "tmpfs /dev/shm tmpfs defaults,nosuid,nodev,noexec,size=512M 0 0" >>/etc/fstab
    fi

    # Remount with secure options
    mount -o remount,nosuid,nodev,noexec /tmp 2>/dev/null || true
    mount -o remount,nosuid,nodev,noexec /dev/shm 2>/dev/null || true

    # Enhanced limits configuration
    CreateBackup "/etc/security/limits.conf"

    cat >>/etc/security/limits.conf <<'EOF'

# Enhanced security limits
* hard core 0
* soft nproc 65536
* hard nproc 65536
* soft nofile 65536
* hard nofile 65536
* hard maxlogins 3
root soft nofile 65536
root hard nofile 65536
EOF

    # Blacklist dangerous kernel modules
    cat >/etc/modprobe.d/proxmox-blacklist.conf <<'EOF'
# Filesystem modules
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true

# Network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install n-hdlc /bin/true
install ax25 /bin/true
install netrom /bin/true
install x25 /bin/true
install rose /bin/true
install decnet /bin/true
install econet /bin/true
install af_802154 /bin/true
install ipx /bin/true
install appletalk /bin/true
install psnap /bin/true
install p8023 /bin/true
install llc /bin/true

# Misc modules
install usb-storage /bin/true
install bluetooth /bin/true
install btusb /bin/true
install firewire-core /bin/true
install thunderbolt /bin/true

# Blacklist entries
blacklist cramfs
blacklist freevxfs
blacklist jffs2
blacklist hfs
blacklist hfsplus
blacklist squashfs
blacklist udf
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
blacklist usb-storage
blacklist bluetooth
blacklist btusb
blacklist firewire-core
blacklist thunderbolt
EOF

    update-initramfs -u

    Log "INFO" "Filesystem security configured"
}
