#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="enhance_ssh_configuration"
module_description="👤 Manage SSH settings and configurations"
version=1.0.0
menu_name=$module_name
menu_description=$module_description

enhance_ssh_configuration() {
    log "INFO" "Starting SSH configuration enhancement..."

    create_backup "/etc/ssh/sshd_config"
    # Daha uyumlu bir şekilde güncelleme
    sed -i '/^KexAlgorithms/d' /etc/ssh/sshd_config
    sed -i '/^Ciphers/d' /etc/ssh/sshd_config
    sed -i '/^MACs/d' /etc/ssh/sshd_config
    # Generate strong DH parameters if not exists

    # Enhanced SSH configuration
    cat >/etc/ssh/sshd_config.new <<'EOF'
# Enhanced SSH Configuration - Proxmox Hardening  v ${SCRIPT_VERSION}
Include /etc/ssh/sshd_config.d/*.conf

# Network settings
Protocol 2
Port 22
AddressFamily inet
ListenAddress 0.0.0.0

# Authentication
PermitRootLogin prohibit-password # make yes if you want to allow root login with password for download ssh keys
PubkeyAuthentication yes # make no if you want to disable public key authentication
PasswordAuthentication no #make yes if you want to allow password authentication
PermitEmptyPasswords no
ChallengeResponseAuthentication no

MaxAuthTries 3
MaxSessions 2
#MaxStartups 10:30:60
LoginGraceTime 30

# Kerberos and GSSAPI
KerberosAuthentication no
GSSAPIAuthentication no

# Forwarding and tunneling
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
GatewayPorts no

# Environment
PermitUserEnvironment no
AcceptEnv LANG LC_*

# Misc settings
UsePAM yes
UseDNS no
TCPKeepAlive no
Compression no
StrictModes yes
HostbasedAuthentication no
IgnoreRhosts yes

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Modern Cryptography

#HostKey /etc/ssh/ssh_host_ed25519_key
#HostKey /etc/ssh/ssh_host_rsa_key

# Key exchange algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256

# Ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# MACs
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com

# Host key algorithms
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-256,rsa-sha2-512

# Client alive settings
ClientAliveInterval 300
ClientAliveCountMax 2

# Banner
Banner /etc/ssh/banner

# User restrictions
AllowUsers root
EOF

    # Validate SSH configuration
    if sshd -t -f /etc/ssh/sshd_config.new; then
        mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config
        log "INFO" "SSH configuration updated successfully"
    else
        log "ERROR" "SSH configuration validation failed"
        rm -f /etc/ssh/sshd_config.new
        return 1
    fi
    if [[ ! -f /etc/ssh/moduli.safe ]]; then
        log "INFO" "Generating safe moduli (this may take a while)..."
        ssh-keygen -M generate -O bits=1024 /tmp/moduli.candidates
        ssh-keygen -M screen -f /tmp/moduli.candidates /etc/ssh/moduli
        rm -f /tmp/moduli.candidates
          chmod 644 /etc/ssh/moduli
    fi
    # Create enhanced SSH banner
cat >/etc/ssh/banner <<'EOF'
********************************************************************************
*                           AUTHORIZED ACCESS ONLY                             *
*                                                                              *
*    This Proxmox VE system is for authorized users only. All activities       *
*    are monitored and logged. Unauthorized access attempts will be            *
*    prosecuted to the full extent of the law.                                 *
*                                                                              *
********************************************************************************
EOF

    chmod 644 /etc/ssh/banner
    log "INFO" "SSH banner created"
}
