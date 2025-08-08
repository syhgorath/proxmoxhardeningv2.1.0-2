#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

service_contents() {
  echo "[INFO] Starting systemd service hardening..."

  SERVICES=(
    "rsyslog.service"
    "postfix@-.service"
    "rc-local.service"
    "rescue.service"
    "console-getty.service"
    "getty@tty1.service"
    "systemd-ask-password-console.service"
    "systemd-ask-password-wall.service"
    "lxcfs.service"
    "corosync.service"
    "cron.service"
    "dbus.service"
    "dm-event.service"
    "emergency.service"
    "fail2ban.service"
    "frr.service"
  )

  declare -A HARDENING_CONTENTS

  HARDENING_CONTENTS["rsyslog.service"]='[Service]
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ReadWritePaths=/var/log
RestrictSUIDSGID=true
SystemCallFilter=@system-service
'

  HARDENING_CONTENTS["postfix@-.service"]='[Service]
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=yes
PrivateTmp=true
RestrictSUIDSGID=true
SystemCallFilter=@system-service
'

  HARDENING_CONTENTS["rc-local.service"]='[Service]
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=true
SystemCallFilter=@system-service
'

  HARDENING_CONTENTS["rescue.service"]='[Service]
NoNewPrivileges=true
PrivateTmp=true
SystemCallFilter=@system-service
'

  HARDENING_CONTENTS["console-getty.service"]='[Service]
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes
NoNewPrivileges=true
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
ReadWritePaths=/run /var/log
RestrictRealtime=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
SystemCallFilter=@system-service
CapabilityBoundingSet=
AmbientCapabilities=
LockPersonality=true
RemoveIPC=yes
'

  HARDENING_CONTENTS["getty@tty1.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'

  HARDENING_CONTENTS["systemd-ask-password-console.service"]='[Service]
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
'

  HARDENING_CONTENTS["systemd-ask-password-wall.service"]='[Service]
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
'

  HARDENING_CONTENTS["lxcfs.service"]='[Service]
# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ReadWritePaths=/var/lib/lxcfs /tmp
ProtectKernelLogs=true

ProtectProc=invisible
SystemCallArchitectures=native
SystemCallErrorNumber=EPERM

LockPersonality=true
MemoryDenyWriteExecute=true
RestrictSUIDSGID=true
RemoveIPC=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=no
SystemCallFilter=~@reboot @debug @obsolete @cpu-emulation @raw-io


'
  HARDENING_CONTENTS["ssh.service"]='[Service]
# Security hardening
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true # for ssh make it false otherwise it will not read the home directory
ProtectSystem=full
ReadWritePaths=/var/log /run /run/sshd
ProtectKernelLogs=true
ProtectClock=true
ProtectHostname=true
ProtectProc=invisible
SystemCallArchitectures=native
# SystemCallFilter=@system-service ssh için bunu sil
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
RestrictRealtime=true
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=false
RestrictSUIDSGID=true
RemoveIPC=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
ExecStartPre=/bin/mkdir -p /run/sshd
ExecStartPre=/bin/chown root:root /run/sshd
ExecStartPre=/bin/chmod 0755 /run/sshd
'
  HARDENING_CONTENTS["corosync.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=no
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'
  HARDENING_CONTENTS["cron.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'
  HARDENING_CONTENTS["dbus.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=no
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'
  HARDENING_CONTENTS["dm-event.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=no
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'
  HARDENING_CONTENTS["emergency.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=no
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'
  HARDENING_CONTENTS["fail2ban.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=no
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'
  HARDENING_CONTENTS["frr.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelTunables=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictNamespaces=no
SystemCallArchitectures=native
SystemCallFilter=@system-service
LockPersonality=yes
MemoryDenyWriteExecute=yes
'
  for service in "${SERVICES[@]}"; do
    target_dir="/etc/systemd/system/${service}.d"
    conf_file="${target_dir}/hardening.conf"
    mkdir -p "$target_dir"
    echo "${HARDENING_CONTENTS[$service]}" >"$conf_file"
    echo "[INFO] Hardened $service"
  done

  systemctl daemon-reexec
  systemctl daemon-reload

  echo "[INFO] Running post-analysis..."
  systemd-analyze security >/etc/proxmox-hardening/security_report_after_service_hardening.txt

  echo "[INFO] systemd service hardening completed."
}