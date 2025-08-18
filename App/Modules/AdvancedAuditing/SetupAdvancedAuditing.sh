#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="SetupAdvancedAuditing"
module_description="🔍 Setup advanced system auditing"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"

SetupAdvancedAuditing() {
    Log "INFO" "Setting up advanced system auditing..."
    if ! dpkg -l auditd &>/dev/null; then
        apt update && apt install -y auditd audispd-plugins
    fi
    CreateBackup "/etc/audit/auditd.conf"
 install -d -m 0750 -o root -g root /var/log/audit


    # Enhanced auditd configuration
    cat >/etc/audit/auditd.conf <<'EOF'
# Enhanced Auditd Configuration
local_events = yes
write_Logs = yes
log_file = /var/log/audit/audit.Log
log_group = adm
log_format = ENRICHED
flush = INCREMENTAL_ASYNC
freq = 50
max_LOG_FILE = 100
num_Logs = 20
priority_boost = 4
disp_qos = lossy
dispatcher = /sbin/audispd
name_format = HOSTNAME
max_LOG_FILE_action = ROTATE
space_left = 200
space_left_action = SYSLog
verify_email = yes
action_mail_acct = root
admin_space_left = 100
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
use_libwrap = yes
#tcp_listen_port = 60
#tcp_listen_queue = 5
#tcp_max_per_addr = 1
#tcp_client_ports = 1024-65535
#tcp_client_max_idle = 0
enable_krb5 = no
krb5_principal = auditd
EOF

    # Comprehensive audit rules
    cat >/etc/audit/rules.d/10-proxmox-hardening.rules <<'EOF'
# Enhanced Proxmox Audit Rules ${SCRIPT_VERSION}
-D
-b 8192
-f 2

# Self monitoring
-w /etc/audit/ -p wa -k auditconfig
-w /etc/libaudit.conf -p wa -k auditconfig
-w /etc/audisp/ -p wa -k audispconfig

# Critical system files
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# SSH monitoring
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /root/.ssh -p wa -k root_ssh
-w /etc/ssh/ -p wa -k ssh_config

# Proxmox specific monitoring
-w /etc/pve/ -p wa -k proxmox_config
-w /usr/bin/pvesh -p x -k proxmox_api
-w /usr/bin/qm -p x -k vm_management
-w /usr/bin/pct -p x -k container_management
-w /usr/bin/pvesm -p x -k storage_management

# Network configuration
-w /etc/hosts -p wa -k network_config
-w /etc/network/ -p wa -k network_config
-w /etc/resolv.conf -p wa -k network_config

# Kernel and system parameters
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/sysctl.d/ -p wa -k sysctl
-w /etc/modprobe.d/ -p wa -k kernel_modules

# Time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
-a always,exit -F arch=b32 -S clock_settime -k time_change
-w /etc/localtime -p wa -k time_change

# Process execution monitoring
-a always,exit -F arch=b64 -S execve -k process_execution
-a always,exit -F arch=b32 -S execve -k process_execution

# Privilege escalation
-w /bin/su -p x -k privilege_escalation
-w /usr/bin/sudo -p x -k privilege_escalation
-w /etc/polkit-1/ -p wa -k polkit

# File system operations
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k file_permissions
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k file_ownership
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k file_ownership

# File deletion monitoring
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k file_deletion
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k file_deletion

# Mount operations
-a always,exit -F arch=b64 -S mount -k mount_operations
-a always,exit -F arch=b32 -S mount -k mount_operations

# Module loading
-w /sbin/insmod -p x -k module_loading
-w /sbin/rmmod -p x -k module_loading
-w /sbin/modprobe -p x -k module_loading
-a always,exit -F arch=b64 -S init_module -S delete_module -k module_loading

# Make configuration immutable
-e 2
EOF

    # Start and enable auditd
    systemctl enable --now auditd.service || true
    augenrules --load || true
    systemctl restart auditd


 auditctl -s
    Log "INFO" "Advanced auditing configured and started"
}
