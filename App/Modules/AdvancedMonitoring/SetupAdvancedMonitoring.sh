#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="SetupAdvancedMonitoring"
module_description="🛡️ setup advanced monitor"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"
SetupAdvancedMonitoring() {
    Log "INFO" "Setting up advanced security monitoring..."

    # Install monitoring tools
    apt update && apt install -y rsyslog logwatch htop iotop nethogs net-tools lynis

    # Enhanced rsyslog configuration
    CreateBackup "/etc/rsyslog.conf"
    cat >>/etc/rsyslog.conf <<'EOF'

# Enhanced logging configuration
$ModLoad imudp
$UDPServerRun 514
$UDPServerAddress 127.0.0.1

# Enhanced Log formats
$template PreciseFormat,"%timegenerated:::date-year%-%timegenerated:::date-month%-%timegenerated:::date-day% %timegenerated:::date-hour%:%timegenerated:::date-minute%:%timegenerated:::date-second%.%timegenerated:::date-subseconds% %hostname% %sysLogtag%%msg%\n"
$ActionFileDefaultTemplate PreciseFormat

# Security event logging
local0.*                        /var/log/security-events.log
auth,authpriv.*                 /var/log/auth.log
*.*;auth,authpriv.none          /var/log/syslog
daemon.*                        /var/log/daemon.log
kern.*                          /var/log/kern.log
lpr.*                           /var/log/lpr.log
mail.*                          /var/log/mail.log
user.*                          /var/log/user.log

# Proxmox specific logging
if $programname startswith 'pve' then /var/log/pve.log
if $programname startswith 'qm' then /var/log/pve-qemu.log
if $programname startswith 'pct' then /var/log/pve-lxc.log

# Emergency messages to all users
*.emerg                         :omusrmsg:*

# Stop processing after Logging to specific files
& stop
EOF

    systemctl restart rsyslog

    # Setup cron jobs for monitoring
    (
        crontab -l 2>/dev/null | grep -v -E "(security-monitor|system-health-monitor)"
        cat <<'EOF'
# Security and health monitoring
0 * * * * /usr/local/bin/security-monitor.sh
*/15 * * * * /usr/local/bin/system-health-monitor.sh
# Weekly security report
0 2 * * 1 /usr/local/bin/proxmox-security-check.sh > /var/log/weekly-security-report.log
EOF
    ) | crontab -

    # Configure logrotate for monitoring logs
    cat >/etc/logrotate.d/security-monitoring <<'EOF'
/var/log/security-monitor.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/log/system-health.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/log/security-events.log {
    weekly
    rotate 26
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/log/weekly-security-report.log {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF

    Log "INFO" "Advanced security monitoring configured"
}
