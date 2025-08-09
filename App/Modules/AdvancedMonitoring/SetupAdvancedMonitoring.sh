#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="SetupAdvancedMonitoring"
module_description="🛡️ setup advanced monitor"
version=1.0.0
RegisterModules $module_name $module_description $group
SetupAdvancedMonitoring() {
    Log "INFO" "Setting up advanced security monitoring..."

    # Install monitoring tools
    apt update && apt install rsysLog Logwatch htop iotop nethogs net-tools -y

    # Enhanced rsysLog configuration
    CreateBackup "/etc/rsysLog.conf"
    cat >>/etc/rsysLog.conf <<'EOF'

# Enhanced Logging configuration
$ModLoad imudp
$UDPServerRun 514
$UDPServerAddress 127.0.0.1

# Enhanced Log formats
$template PreciseFormat,"%timegenerated:::date-year%-%timegenerated:::date-month%-%timegenerated:::date-day% %timegenerated:::date-hour%:%timegenerated:::date-minute%:%timegenerated:::date-second%.%timegenerated:::date-subseconds% %hostname% %sysLogtag%%msg%\n"
$ActionFileDefaultTemplate PreciseFormat

# Security event Logging
local0.*                        /var/Log/security-events.Log
auth,authpriv.*                 /var/Log/auth.Log
*.*;auth,authpriv.none          /var/Log/sysLog
daemon.*                        /var/Log/daemon.Log
kern.*                          /var/Log/kern.Log
lpr.*                          /var/Log/lpr.Log
mail.*                         /var/Log/mail.Log
user.*                         /var/Log/user.Log

# Proxmox specific Logging
if $programname startswith 'pve' then /var/Log/pve.Log
if $programname startswith 'qm' then /var/Log/pve-qemu.Log
if $programname startswith 'pct' then /var/Log/pve-lxc.Log

# Emergency messages to all users
*.emerg                         :omusrmsg:*

# Stop processing after Logging to specific files
& stop
EOF

    systemctl restart rsysLog

    # Setup cron jobs for monitoring
    (
        crontab -l 2>/dev/null | grep -v -E "(security-monitor|system-health-monitor)"
        cat <<'EOF'
# Security and health monitoring
0 * * * * /usr/local/bin/security-monitor.sh
*/15 * * * * /usr/local/bin/system-health-monitor.sh
# Weekly security report
0 2 * * 1 /usr/local/bin/proxmox-security-check.sh > /var/Log/weekly-security-report.Log
EOF
    ) | crontab -

    # Configure Logrotate for monitoring Logs
    cat >/etc/Logrotate.d/security-monitoring <<'EOF'
/var/Log/security-monitor.Log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/Log/system-health.Log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/Log/security-events.Log {
    weekly
    rotate 26
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/Log/weekly-security-report.Log {
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
