#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="hardening"
module_name="SetupFileIntegrity"
module_description="🛡️ apply file integrity"
version=1.0.0
RegisterModules $module_name $module_description $group

SetupFileIntegrity() {
    Log "INFO" "Setting up advanced file integrity monitoring..."

    # Install AIDE
    if ! command -v aide &>/dev/null; then
        apt update && apt install aide aide-common -y
    fi

    CreateBackup "/etc/aide/aide.conf"

    # Enhanced AIDE configuration
    cat >/etc/aide/aide.conf <<'EOF'
# Enhanced AIDE Configuration for Proxmox
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
database_new=file:/var/lib/aide/aide.db.new
gzip_dbout=yes

report_url=file:/var/log/aide/aide.log
report_url=stdout
summarize_changes=yes

# Custom rules
Binlib = p+i+n+u+g+s+b+m+c+md5+sha1+sha256
ConfFiles = p+i+n+u+g+s+b+m+c+md5+sha1+sha256
logs = p+i+n+u+g+s+b+m+c+md5+sha1+sha256
Devices = p+i+n+u+g+s+b+c+md5+sha1+sha256
Databases = p+i+n+u+g+s+b+m+c+md5+sha1+sha256

# System binaries
/bin Binlib
/sbin Binlib
/usr/bin Binlib
/usr/sbin Binlib
/usr/local/bin Binlib
/usr/local/sbin Binlib

# Configuration files
/etc ConfFiles
!/etc/mtab
!/etc/passwd-
!/etc/group-
!/etc/shadow-
!/etc/gshadow-
!/etc/security/opasswd
!/etc/ssh/ssh_host_key
!/etc/ssh/ssh_host_key.pub
!/etc/ssh/ssh_host_rsa_key
!/etc/ssh/ssh_host_rsa_key.pub
!/etc/ssh/ssh_host_dsa_key
!/etc/ssh/ssh_host_dsa_key.pub
!/etc/ssh/ssh_host_ecdsa_key
!/etc/ssh/ssh_host_ecdsa_key.pub
!/etc/ssh/ssh_host_ed25519_key
!/etc/ssh/ssh_host_ed25519_key.pub

# Proxmox specific
/etc/pve ConfFiles
/usr/share/perl5/PVE ConfFiles
/usr/share/pve-manager ConfFiles

# System libraries
/lib Binlib
/lib64 Binlib
/usr/lib Binlib
/usr/lib64 Binlib

# Boot and kernel
/boot Binlib

# Critical system files
/root/\.ssh ConfFiles

# Device files
/dev Devices

# Temporary and variable files (selective monitoring)
!/var/log/.*
!/var/cache/.*
!/var/tmp/.*
!/tmp/.*
!/proc/.*
!/sys/.*
!/dev/pts/.*
!/dev/shm/.*
!/var/lib/aide/aide.db.*
!/var/lib/dhcp/.*
!/var/run/.*
!/var/lock/.*
!/var/spool/.*
EOF

    # Initialize AIDE database
    if [[ ! -f /var/lib/aide/aide.db ]]; then
        Log "INFO" "Initializing AIDE database (this may take several minutes)..."
        aideinit
        if [[ -f /var/lib/aide/aide.db.new ]]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        fi
    fi

    # Create AIDE check script
    cat >/usr/local/bin/aide-check.sh <<'EOF'
#!/bin/bash
# Enhanced AIDE Check Script

AIDE_Log="/var/log/aide/aide.log"
AIDE_REPORT="/var/log/aide/aide-report-$(date +%Y%m%d-%H%M%S).log"
EMAIL_ALERT=""  # Set email for alerts

# Create Log directory
mkdir -p /var/log/aide

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting AIDE file integrity check" | tee -a "$AIDE_Log"

# Run AIDE check
/usr/bin/aide --check --config /etc/aide/aide.conf > "$AIDE_REPORT" 2>&1
AIDE_STATUS=$?

case $AIDE_STATUS in
    0)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: No changes detected" | tee -a "$AIDE_Log"
        ;;
    1)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: New files added" | tee -a "$AIDE_Log"
        ;;
    2)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: Files removed" | tee -a "$AIDE_Log"
        ;;
    3)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: Files changed" | tee -a "$AIDE_Log"
        ;;
    4)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: Files added and removed" | tee -a "$AIDE_Log"
        ;;
    5)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: Files added and changed" | tee -a "$AIDE_Log"
        ;;
    6)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: Files removed and changed" | tee -a "$AIDE_Log"
        ;;
    7)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check completed: Files added, removed and changed" | tee -a "$AIDE_Log"
        ;;
    *)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - AIDE check failed with status: $AIDE_STATUS" | tee -a "$AIDE_Log"
        ;;
esac

# Log to sysLog
logger -t "aide-check" "AIDE integrity check completed with status: $AIDE_STATUS"

# Optional email notification
if [[ -n "$EMAIL_ALERT" && $AIDE_STATUS -ne 0 ]]; then
    mail -s "AIDE Alert: File integrity changes detected on $(hostname)" "$EMAIL_ALERT" < "$AIDE_REPORT"
fi

# Cleanup old reports (keep last 30 days)
find /var/log/aide/ -name "aide-report-*.log" -mtime +30 -delete

exit $AIDE_STATUS
EOF

    chmod +x /usr/local/bin/aide-check.sh

    # Setup cron job for daily AIDE checks
    (
        crontab -l 2>/dev/null | grep -v aide-check
        echo "0 3 * * * /usr/local/bin/aide-check.sh"
    ) | crontab -

    # Configure Logrotate for AIDE
    cat >/etc/logrotate.d/aide <<'EOF'
/var/log/aide/aide.log {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/log/aide/aide-report-*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF

    Log "INFO" "File integrity monitoring with AIDE configured"
}
