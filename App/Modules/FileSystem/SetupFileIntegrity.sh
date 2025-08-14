#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="hardening"
module_name="SetupFileIntegrity"
module_description="🛡️ apply file integrity"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"

SetupFileIntegrity() {
    Log "INFO" "Setting up advanced file integrity monitoring..."

    # Install AIDE
    if ! command -v aide &>/dev/null; then
        apt update && apt install aide aide-common -y
    fi

    CreateBackup "/etc/aide/aide.conf"

    # Enhanced AIDE configuration
    tee /etc/aide/aide.conf.d/99-proxmox-rules.conf >/dev/null <<'EOF'



# 99-proxmox-rules.conf — Proxmox özel kurallar (sadece path ve filtreler)
# NOT: Global ayarlar (database_*, report_*, Checksums vb.) ana dosyada olmalı.

# Sistem ikilileri
/bin               Full
/sbin              Full
/usr/bin           Full
/usr/sbin          Full
/usr/local/bin     Full
/usr/local/sbin    Full

# Kütüphaneler
/lib               Full
/lib64             Full
/usr/lib           Full
/usr/lib64         Full

# Boot & kernel
/boot              Full

# Konfigürasyonlar (bazı güvenli hariç tutmalarla)
/etc               Full
!regex:^/etc/mtab$
!regex:^/etc/(passwd-|group-|shadow-|gshadow-|security/opasswd)$
!regex:^/etc/ssh/ssh_host_.*$

# Proxmox özel yolları
/etc/pve                 Full
/usr/share/perl5/PVE     Full
/usr/share/pve-manager   Full

# Hassas kullanıcı anahtarları
/root/.ssh          Full

# Gürültü (volatile) yollar — rapor gürültüsünü azalt
!regex:^/dev(/.*)?$
!regex:^/proc(/.*)?$
!regex:^/sys(/.*)?$
!regex:^/run(/.*)?$
!regex:^/tmp(/.*)?$
!regex:^/var/tmp(/.*)?$
!regex:^/var/cache(/.*)?$
!regex:^/var/log/.*\.gz$
!regex:^/var/log/(wtmp|btmp|lastlog)$
!regex:^/var/lib/aide(/.*)?$
!regex:^/var/lib/docker(/.*)?$
!regex:^/lost\+found(/.*)?$
!regex:^/dev/pts(/.*)?$
!regex:^/dev/shm(/.*)?$
!regex:^/var/lib/dhcp(/.*)?$
!regex:^/var/lock(/.*)?$
!regex:^/var/spool(/.*)?$
EOF
    sed -i 's/\<sha1\>//g' /etc/aide/aide.conf
    sed -i 's/^NORMAL.*/NORMAL = p+i+n+u+g+s+m+c+acl+xattrs+sha512/' /etc/aide/aide.conf
    # Initialize AIDE database
    if [[ ! -f /var/lib/aide/aide.db ]]; then
        Log "INFO" "Initializing AIDE database (this may take several minutes)..."
        aide -D -c /etc/aide/aide.conf --log-level=debug
        install -d -m 0700 /var/lib/aide
        aide --init -c /etc/aide/aide.conf
        if [[ -f /var/lib/aide/aide.db.new ]]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        fi
    fi
    aide --check -c /etc/aide/aide.conf
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

    chmod 600 /etc/crontab
    chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly
    groupadd -r proc || true
    usermod -aG proc $(whoami)
    echo 'proc /proc proc defaults,hidepid=2,gid=proc 0 0' | tee -a /etc/fstab
    mount -o remount /proc

    ln -sf /boot/vmlinuz-$(uname -r) /vmlinuz
    ln -sf /boot/initrd.img-$(uname -r) /initrd.img
    Log "INFO" "File integrity monitoring with AIDE configured"
}
