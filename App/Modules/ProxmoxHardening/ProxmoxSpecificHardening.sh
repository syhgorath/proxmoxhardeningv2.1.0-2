#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="hardening"
module_name="ApplyProxmoxSpecificHardening"
module_description="🛡️ Apply Proxmox-specific security hardening"
version=1.0.0
RegisterModules $module_name $module_description $group

ApplyProxmoxSpecificHardening() {
    Log "INFO" "Applying Proxmox-specific security hardening..."

    # Enhanced datacenter configuration
    mkdir -p /etc/pve/local

    if [[ -f /etc/pve/datacenter.cfg ]]; then
        cat >/etc/pve/datacenter.cfg <<'EOF'
# Enhanced Proxmox Datacenter Configuration
keyboard: tr
console: xtermjs
email_from: root@proxmox
max_workers: 4
fencing: watchdog
migration: secure,network=10.1.10.0/24

 
EOF
    fi

    # Create enhanced firewall configuration
    mkdir -p /etc/pve/firewall

    cat >/etc/pve/firewall/cluster.fw <<'EOF'
[OPTIONS]
enable: 1
ebtables: 1
policy_in: DROP
policy_out: ACCEPT


[IPSET management_nets] # Management networks
10.1.10.0/24
172.16.0.0/12
192.168.0.0/16
10.8.0.0/24

[IPSET trusted_hosts] # Trusted management hosts
# Add your management IPs here
# 192.168.1.100
10.1.10.6
10.1.10.4
10.8.0.2
10.1.10.11
[RULES]
GROUP secure_management -i vmbr0
IN ACCEPT -i lo
IN ACCEPT -p icmp
IN ACCEPT -p tcp -dport 22 -source +trusted_hosts
IN ACCEPT -p tcp -dport 8006 -source +trusted_hosts


[group secure_management]
IN ACCEPT -p tcp -dport 22 -source +trusted_hosts
IN ACCEPT -p tcp -dport 8006 -source +trusted_hosts
IN ACCEPT -p tcp -dport 5900:5999 -source +trusted_hosts # VNC
IN ACCEPT -p tcp -dport 3128 -source +trusted_hosts # SPICE

EOF

    # Local host firewall
    cat >/etc/pve/local/host.fw <<'EOF'
[OPTIONS]
enable: 1

Log_level_in: info
Log_level_out: info

[RULES]
IN ACCEPT -i lo
IN ACCEPT -p icmp -icmp-type echo-request
IN ACCEPT -p tcp -dport 22 -source +management_nets
IN ACCEPT -p tcp -dport 8006 -source +management_nets
IN ACCEPT -p tcp -dport 85 -source +management_nets # pveproxy-ssl
IN ACCEPT -p tcp -dport 5900:5999 -source +management_nets # VNC
IN ACCEPT -p tcp -dport 3128 -source +management_nets # SPICE proxy
IN ACCEPT -p udp -dport 5404:5405 # Corosync (cluster)
IN ACCEPT -p tcp -dport 111 -source +management_nets # RPC
IN ACCEPT -p udp -dport 111 -source +management_nets # RPC
IN REJECT
EOF

    # Enhanced Proxmox web interface configuration
    if [ -f /etc/default/pveproxy ]; then
        create_backup "/etc/default/pveproxy"
    fi
    cat >/etc/default/pveproxy <<'EOF'
# Proxmox VE proxy server configuration

# Security headers
POLICY=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; font-src 'self'; object-src 'none'; media-src 'self'; child-src 'self'; frame-ancestors 'none';\"

# SSL/TLS configuration
CIPHERS="ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
SSL_OPTIONS="NO_SSLv3,NO_TLSv1,NO_TLSv1.1"
EOF
    # SPICE Proxy ayarları
    if [ -f "/etc/default/spiceproxy" ]; then
        create_backup "/etc/default/spiceproxy"
        cat >"/etc/default/spiceproxy" <<'EOF'
# SPICE Proxy Security Configuration
SECURE=1
MAX_CONNECTIONS=50
EOF
    fi
    # Configure Logrotate for Proxmox Logs
    cat >/etc/Logrotate.d/proxmox-security <<'EOF'
/var/Log/pveproxy/access.Log {
    weekly
    rotate 52
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    postrotate
        systemctl reload pveproxy
    endscript
}

/var/Log/pvedaemon.Log {
    weekly
    rotate 52
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}

/var/Log/pve-firewall.Log {
    weekly
    rotate 26
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF

    # Enable and configure Proxmox firewall
    if command -v pve-firewall &>/dev/null; then
        systemctl enable pve-firewall
        systemctl restart pve-firewall
        pve-firewall compile
        Log "INFO" "Proxmox firewall enabled and configured"
    fi

    # Restart Proxmox services
    systemctl restart pvedaemon
    systemctl restart pveproxy
    systemctl restart spiceproxy 2>/dev/null || true
    Log "INFO" "PVEProxy and SPICE proxy security enhanced"

    Log "INFO" "Proxmox-specific hardening applied"
}
