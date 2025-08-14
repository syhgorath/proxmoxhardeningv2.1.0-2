#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
# Function to create comprehensive backup script
group="hardening"
module_name="CreateBackUpScript"
module_description="💾 create backup script"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"
CreateBackUpScript() {
    cat >/usr/local/bin/proxmox-config-backup.sh <<'EOF'
#!/bin/bash
# Comprehensive Proxmox Configuration Backup Script

readonly BACKUP_BASE_DIR="/var/backups/proxmox-security"
readonly DATE_STAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_DIR="${BACKUP_BASE_DIR}/${DATE_STAMP}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting Proxmox configuration backup to $BACKUP_DIR"

# Backup critical configuration files
config_files=(
    "/etc/ssh/sshd_config"
    "/etc/pve"
    "/etc/audit"
    "/etc/fail2ban"
    "/etc/apparmor.d"
    "/etc/sysctl.d"
    "/etc/systemd/system"
    "/etc/cron.d"
    "/etc/cron.allow"
    "/etc/sudoers*"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/gshadow"
    "/etc/security"
    "/usr/local/bin/proxmox-security-check.sh"
    "/usr/local/bin/security-monitor.sh"
    "/usr/local/bin/system-health-monitor.sh"
)

for item in "${config_files[@]}"; do
    if [[ -e "$item" ]]; then
        cp -r "$item" "$BACKUP_DIR/" 2>/dev/null
        echo "Backed up: $item"
    fi
done

# Create system state snapshot
{
    echo "=== SYSTEM STATE SNAPSHOT ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "Proxmox Version: $(pveversion)"
    echo ""
    echo "=== RUNNING SERVICES ==="
    systemctl list-units --type=service --state=active
    echo ""
    echo "=== NETWORK CONFIGURATION ==="
    ip addr show
    echo ""
    echo "=== FIREWALL STATUS ==="
    pve-firewall status 2>/dev/null || echo "PVE Firewall not available"
    echo ""
    echo "=== PACKAGE LIST ==="
    dpkg -l
} > "$BACKUP_DIR/system-state.txt"

# Compress backup
cd "$BACKUP_BASE_DIR"
tar -czf "proxmox-security-backup-${DATE_STAMP}.tar.gz" "$DATE_STAMP"
rm -rf "$DATE_STAMP"

# Cleanup old backups (keep last 30 days)
find "$BACKUP_BASE_DIR" -name "proxmox-security-backup-*.tar.gz" -mtime +30 -delete

echo "Backup completed: proxmox-security-backup-${DATE_STAMP}.tar.gz"
echo "Backup location: $BACKUP_BASE_DIR"
EOF

    chmod +x /usr/local/bin/proxmox-config-backup.sh

    # Add weekly backup to crontab
    (
        crontab -l 2>/dev/null | grep -v proxmox-config-backup
        echo "0 2 * * 0 /usr/local/bin/proxmox-config-backup.sh"
    ) | crontab -

    Log "INFO" "Comprehensive backup script created"
}
