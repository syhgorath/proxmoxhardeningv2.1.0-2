#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="EnhancedSSHConfiguration"
module_description="👤 Manage SSH settings and configurations"
version=1.0.0
RegisterModules $module_name $module_description $group
EnhancedSSHConfiguration() {
    Log "INFO" "Starting SSH configuration enhancement..."

    install -d -m0755 /run/sshd
    install -d -m0755 /etc/ssh/sshd_config.d
    CreateBackup "/etc/ssh/sshd_config"

    # Yeni sshd_config (OpenSSH 9-safe)
    cat >/etc/ssh/sshd_config.new <<EOF
# Enhanced SSH Configuration - Proxmox Hardening v ${SCRIPT_VERSION}
Include /etc/ssh/sshd_config.d/*.conf

# ===== Hardened (OpenSSH 9-safe) =====
Protocol 2
UsePAM yes
UseDNS no
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
TCPKeepAlive no
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 20
MaxAuthTries 3
MaxSessions 5
MaxStartups 10:30:60
IgnoreRhosts yes
HostbasedAuthentication no
StrictModes yes
GSSAPIAuthentication no

# Logging
SyslogFacility AUTHPRIV
LogLevel VERBOSE

# Banner
Banner /etc/ssh/banner

# User restrictions (isteğe göre düzenle veya yorum yap)
# AllowUsers root
EOF
    # ENV veya Definitions.cfg’den ALLOW_SSH_USERS gelirse uygula
if [[ -n "${ALLOW_SSH_USERS:-}" ]]; then
    sed -i '/^#\? *AllowUsers/d' /etc/ssh/sshd_config
    echo "AllowUsers ${ALLOW_SSH_USERS}" >> /etc/ssh/sshd_config
fi
    # Doğrula ve uygula
    if sshd -t -f /etc/ssh/sshd_config.new; then
        mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config
        chmod 600 /etc/ssh/sshd_config
        Log "INFO" "SSH configuration updated successfully"
    else
        Log "ERROR" "SSH configuration validation failed"
        rm -f /etc/ssh/sshd_config.new
        return 1
    fi

    # Moduli: 3072+ bit şartı (mevcut varsa filtrele, yoksa üret)
    if [[ -s /etc/ssh/moduli ]]; then
        awk '$5 >= 3072' /etc/ssh/moduli >/etc/ssh/moduli.safe || true
        if [[ -s /etc/ssh/moduli.safe ]]; then
            mv -f /etc/ssh/moduli.safe /etc/ssh/moduli
        fi
    else
        Log "INFO" "Generating 3072-bit DH moduli (this may take a while)..."
        ssh-keygen -M generate -O bits=3072 /tmp/moduli.candidates
        ssh-keygen -M screen -f /tmp/moduli.candidates /etc/ssh/moduli
        rm -f /tmp/moduli.candidates
    fi
    chmod 644 /etc/ssh/moduli || true

    # Banner
    cat >/etc/ssh/banner <<'EOF'
********************************************************************************
*                           AUTHORIZED ACCESS ONLY                             *
*                                                                              *
*  This Proxmox VE system is for authorized users only. All activities are     *
*  monitored and logged. Unauthorized access attempts will be prosecuted.      *
*                                                                              *
********************************************************************************
EOF
    chmod 644 /etc/ssh/banner

    # Güvenli yeniden yükleme
    if sshd -t; then
        systemctl try-reload-or-restart ssh || systemctl restart ssh
    fi

    Log "INFO" "SSH banner created and service reloaded"

}
