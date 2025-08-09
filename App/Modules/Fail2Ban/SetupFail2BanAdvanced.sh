#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="SetupFail2BanAdvanced"
module_description="🛡️ setup fail2ban"
version=1.0.0
RegisterModules $module_name $module_description $group
SetupFail2BanAdvanced() {
    Log "INFO" "Setting up advanced Fail2Ban configuration..."

    # Install Fail2Ban
    create_backup "/etc/fail2ban/jail.local"

    # Advanced Fail2Ban configuration
    cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
# Global settings

bantime = 86400
findtime = 3600
maxretry = 3
backend = systemd
allowipv6 = auto
usedns = warn
Logencoding = auto
enabled = false
mode = normal
filter = %(__name__)s[mode=%(mode)s]
destemail = root@localhost
sender = fail2ban@localhost
mta = sendmail
protocol = tcp
chain = <known/chain>
port = 0:65535
fail2ban_agent = Fail2Ban/%(fail2ban_version)s

# Actions
banaction = iptables-multiport
banaction_allports = iptables-allports
action = %(action_)s

[sshd]
enabled = true
port = ssh
filter = sshd
#Logpath = /var/Log/auth.Log
maxretry = 3
bantime = 86400
findtime = 3600

[sshd-ddos]
enabled = false
port = ssh
filter = sshd-ddos
#Logpath = /var/Log/auth.Log
maxretry = 6
bantime = 86400
findtime = 3600

[proxmox-web]
enabled = true
port = 8006
filter = proxmox-web
Logpath = /var/Log/daemon.Log
maxretry = 3
bantime = 86400
findtime = 3600

[nginx-proxmox]
enabled  = true
port     = 8006
filter   = nginx-proxmox
Logpath  = /var/Log/nginx/error.Log
maxretry = 3
bantime  = 1d

[proxmox-api]
enabled = true
port = 8006
filter = proxmox-api
Logpath = /var/Log/pveproxy/access.Log 
maxretry = 5
bantime = 86400
findtime = 3600

[apache-auth]
enabled = false

[apache-badbots]
enabled = false

[apache-noscript]
enabled = false

[apache-overflows]
enabled = false

[apache-nohome]
enabled = false

[apache-botsearch]
enabled = false

[postfix]
enabled = false

[postfix-sasl]
enabled = false

[dovecot]
enabled = false

[recidive]
enabled = true
filter = recidive
Logpath = /var/Log/fail2ban.Log
action = %(action_mwl)s
bantime = 604800
findtime = 86400
maxretry = 5
EOF

    # Create Proxmox-specific filters
    cat >/etc/fail2ban/filter.d/proxmox-web.conf <<'EOF'
[Definition]
failregex = pvedaemon\[.*\]: authentication failure; rhost=<HOST> user=.* msg=.*
            pveproxy\[.*\]: authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

    cat >/etc/fail2ban/filter.d/proxmox-api.conf <<'EOF'
[Definition]
failregex = pvedaemon\[.*\]: <HOST> - authentication failure.*
            pvesh\[.*\]: <HOST> - authentication failure.*
ignoreregex =
EOF

    # Create advanced action for notification
    cat >/etc/fail2ban/action.d/mail-whois-lines.local <<'EOF'
[Definition]
actionstart = printf %%b "Hi,\n
              The jail <name> has been started successfully.\n
              Regards,\n
              Fail2Ban" | mail -s "[Fail2Ban] <name>: started on <fq-hostname>" <dest>

actionstop = printf %%b "Hi,\n
             The jail <name> has been stopped.\n
             Regards,\n
             Fail2Ban" | mail -s "[Fail2Ban] <name>: stopped on <fq-hostname>" <dest>

actioncheck =

actionban = printf %%b "Hi,\n
            The IP <ip> has just been banned by Fail2Ban after
            <failures> attempts against <name>.\n\n
            Here is more information about <ip>:\n
            `/usr/bin/whois <ip> | grep -v "^%%"`\n
            Regards,\n
            Fail2Ban" | mail -s "[Fail2Ban] <name>: banned <ip> from <fq-hostname>" <dest>

actionunban =

[Init]
name = default
dest = root
EOF

    # Enable and start Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban

    Log "INFO" "Advanced Fail2Ban configured and started"
}
