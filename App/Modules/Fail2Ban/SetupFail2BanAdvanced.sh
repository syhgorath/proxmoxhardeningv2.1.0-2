#!/bin/bash
#set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="SetupFail2BanAdvanced"
module_description="🛡️ Setup advanced Fail2Ban configuration"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"

SetupFail2BanAdvanced() {
    Log "INFO" "Setting up advanced Fail2Ban configuration..."

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y fail2ban || {
        echo "fail2ban install failed"
        exit 1
    }

    # ---- Banaction autodetect (prefer nftables, fallback iptables) ----
    if command -v nft >/dev/null 2>&1; then
        ACTION_MULTI="nftables-multiport"
        ACTION_ALL="nftables-allports"
    else
        ACTION_MULTI="iptables-multiport"
        ACTION_ALL="iptables-allports"
    fi
    Log "INFO" "Fail2Ban actions → ${ACTION_MULTI} / ${ACTION_ALL}"

    # ---- Filters (single, canonical versions) ----
    install -d -m 755 /etc/fail2ban/filter.d

    # pveproxy auth failure'ları (journald/syslog)
    tee /etc/fail2ban/filter.d/proxmox-web.conf >/dev/null <<'EOF'
[Definition]
failregex = ^\w{3}\s+\d+\s[\d:]+ [._\w-]+ pveproxy\[\d+\]: authentication failure;.* rhost=<HOST>
ignoreregex =
EOF

    # pveproxy access.log'daki 401 ticket istekleri
    tee /etc/fail2ban/filter.d/proxmox-api.conf >/dev/null <<'EOF'
[Definition]
failregex = ^<HOST> - - \[.*\] "POST /api2/json/access/ticket HTTP/1\.[01]" 401
ignoreregex =
EOF

    # Nginx reverse-proxy üzerinden PVE'ye gidiyorsan (access.log 401)
    tee /etc/fail2ban/filter.d/nginx-proxmox.conf >/dev/null <<'EOF'
[Definition]
failregex = ^<HOST> - - \[.*\] "POST /api2/json/access/ticket HTTP/1\.[01]" 401
ignoreregex =
EOF

    # ---- jail.local (clean) ----
    CreateBackup "/etc/fail2ban/jail.local"
    cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime   = 1d
findtime  = 1h
maxretry  = 3
backend   = systemd
allowipv6 = auto
usedns    = warn
logencoding = auto
enabled   = false
mode      = normal
filter    = %(__name__)s[mode=%(mode)s]
destemail = root@localhost
sender    = fail2ban@localhost
mta       = sendmail

banaction          = ${ACTION_MULTI}
banaction_allports = ${ACTION_ALL}

[sshd]
enabled  = true
port     = ssh
filter   = sshd
maxretry = 3
bantime  = 1d
findtime = 1h

[proxmox-web]
enabled  = true
port     = 8006
filter   = proxmox-web
backend  = systemd
maxretry = 3
bantime  = 1d
findtime = 1h

[proxmox-api]
enabled  = true
port     = 8006
backend  = auto
filter   = proxmox-api
logpath  = /var/log/pveproxy/access.log
maxretry = 5
bantime  = 1d
findtime = 1h

# Nginx reverse-proxy kullanıyorsan bu jail'i enable edeceğiz (aşağıda otomatik)
[nginx-proxmox]
enabled  = false
port     = 8006
backend  = auto
filter   = nginx-proxmox
logpath  = /var/log/nginx/access.log
maxretry = 3
bantime  = 1d

[recidive]
enabled   = true
filter    = recidive
logpath   = /var/log/fail2ban.log
banaction = ${ACTION_ALL}
bantime   = 7d
findtime  = 1d
maxretry  = 5
action    = %(action_)s
EOF

    # ---- Nginx tespiti: varsa nginx-proxmox jail'ini aç ----
    if systemctl list-unit-files | grep -q '^nginx.service'; then
        if [ -f /var/log/nginx/access.log ]; then
            sed -i 's/^\(\[nginx-proxmox\][^\n]*\n\)enabled\s*=\s*false/\1enabled = true/' /etc/fail2ban/jail.local || true
            Log "INFO" "Enabled nginx-proxmox jail (nginx detected)"
        else
            Log "WARN" "nginx.service var ama /var/log/nginx/access.log yok → nginx-proxmox jail disabled"
        fi
    else
        Log "INFO" "nginx not found → nginx-proxmox jail disabled"
    fi

    # ---- Yapılandırmayı test et ve başlat ----
    systemctl enable fail2ban >/dev/null || true
    # Opsiyonel: örnek regex testi (log varsa)
    [ -f /var/log/daemon.log ] && fail2ban-regex /var/log/daemon.log /etc/fail2ban/filter.d/proxmox-web.conf -v || true
    [ -f /var/log/pveproxy/access.log ] && fail2ban-regex /var/log/pveproxy/access.log /etc/fail2ban/filter.d/proxmox-api.conf -v || true

    systemctl restart fail2ban
    sleep 1
    fail2ban-client status | sed -n '1,200p'
    Log "INFO" "Advanced Fail2Ban configured and started"
}
