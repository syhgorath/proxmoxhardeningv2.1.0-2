#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="ServiceContents"
module_description="🛡️ apply service hardening"
version=1.0.0

ServiceContents() {
  echo "[INFO] Starting systemd service hardening..."

  SERVICES=(
    "rsyslog.service"
    "postfix@-.service"
    "systemd-journald.service"
    "systemd-udevd.service"
    "systemd-logind.service"
    "cron.service"
    "fail2ban.service"
    "getty@tty1.service"
    "lxcfs.service"
    "dbus.service"
    # PVE çekirdekleri (hafif ya da pas geçilecek)
    "pveproxy.service"
    "pvedaemon.service"
    "pve-cluster.service"
    "pve-ha-crm.service"
    "pve-ha-lrm.service"
    "corosync.service"
  )

  declare -A HARDENING_CONTENTS

  HARDENING_CONTENTS["rsyslog.service"]='[Service]
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log
RestrictSUIDSGID=yes
RestrictNamespaces=yes
SystemCallFilter=@system-service
LockPersonality=yes
'
  HARDENING_CONTENTS["systemd-udevd.service"]='[Service]
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
PrivateTmp=yes
LockPersonality=yes
'
  HARDENING_CONTENTS["postfix@-.service"]='[Service]
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=yes
PrivateTmp=true
RestrictSUIDSGID=true
SystemCallFilter=@system-service
'
  HARDENING_CONTENTS["systemd-logind.service"]='[Service]
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
LockPersonality=yes
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
ReadWritePaths=/run /var/Log
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
ProtectSystem=full
ProtectHome=yes
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
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
'
  HARDENING_CONTENTS["ssh.service"]='[Service]
# Security hardening
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true # for ssh make it false otherwise it will not read the home directory
ProtectSystem=full
ReadWritePaths=/var/Log /run /run/sshd
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

 HARDENING_CONTENTS["cron.service"]='[Service]
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
RestrictSUIDSGID=yes
LockPersonality=yes
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
  HARDENING_CONTENTS["pveproxy.service"]='[Service]
NoNewPrivileges=yes
'

  HARDENING_CONTENTS["pvedaemon.service"]='[Service]
NoNewPrivileges=yes
'

  HARDENING_CONTENTS["pve-cluster.service"]='[Service]
NoNewPrivileges=yes
'

  HARDENING_CONTENTS["pve-ha-crm.service"]='[Service]
NoNewPrivileges=yes
'

  HARDENING_CONTENTS["pve-ha-lrm.service"]='[Service]
NoNewPrivileges=yes
'

  HARDENING_CONTENTS["corosync.service"]='[Service]

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
