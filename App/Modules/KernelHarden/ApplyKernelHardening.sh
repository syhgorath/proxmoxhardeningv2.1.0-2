#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="hardening"
module_name="ApplyKernelHardening"
module_description="🛡️ Applying advanced kernel hardening parameters...."
version=1.0.0
RegisterModules $module_name $module_description $group
ApplyKernelHardening() {
    Log "INFO" "Applying advanced kernel hardening parameters..."

    CreateBackup "/etc/sysctl.conf"

    cat >/etc/sysctl.d/99-proxmox-hardening-v2.conf <<'EOF'
# Enhanced Proxmox Kernel Hardening ${SCRIPT_VERSION}

# ===== KERNEL SECURITY =====
# Address Space Layout Randomization
kernel.randomize_va_space = 2
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16

# Kernel pointer restrictions
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3

# BPF and JIT hardening
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
net.core.bpf_jit_kallsyms = 0

# Process restrictions
kernel.yama.ptrace_scope = 2
kernel.perf_event_paranoid = 3
kernel.unprivileged_userns_clone = 0
vm.unprivileged_userfaultfd = 0

# System control restrictions

kernel.core_uses_pid = 1
kernel.ctrl-alt-del = 0
kernel.kexec_load_disabled = 1

# TTY security
dev.tty.ldisc_autoload = 0

# ===== MEMORY MANAGEMENT =====
# Memory protection
vm.mmap_min_addr = 65536
vm.swappiness = 1
vm.dirty_ratio = 3
vm.dirty_background_ratio = 2
vm.page-cluster = 0
vm.vfs_cache_pressure = 50

# OOM killer adjustments
vm.oom_kill_allocating_task = 1
vm.overcommit_memory = 1
vm.overcommit_ratio = 80

#Module loading restrictions
kernel.modules_disabled = 1
# ===== NETWORK SECURITY =====
# IP forwarding (required for Proxmox)
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding=0
net.ipv6.conf.all.forwarding = 1

# TCP hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0
net.ipv4.tcp_dsack = 0
net.ipv4.tcp_fack = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_congestion_control = bbr

# Source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log suspicious packets
net.ipv4.conf.all.Log_martians = 1
net.ipv4.conf.default.Log_martians = 1

# ICMP settings
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Network performance and security
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backLog = 5000
net.core.somaxconn = 65535

# ===== FILESYSTEM SECURITY =====
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0

# ===== ADDITIONAL SECURITY =====
# Restrict access to kernel Logs
kernel.dmesg_restrict = 1

# Restrict access to /proc/kallsyms
kernel.kptr_restrict = 2

# Disable magic SysRq key (except for sync/reboot)
kernel.sysrq = 0
EOF

    # Apply sysctl settings
    sysctl --system

    Log "INFO" "Kernel hardening parameters applied"


}
