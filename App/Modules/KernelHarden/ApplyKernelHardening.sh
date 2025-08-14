#!/usr/bin/env bash
# Proxmox VE 9 — Safe Kernel Hardening (combined)
# Version: 3.0.0 (levels + dry-run + per-key apply + prune + revert)
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="ApplyKernelHardening"
module_description="Kernel hardening (safe, levels, dry-run, per-key apply)"
version=1.0.0
group="hardening"

# =========================
# Fallbacks (module framework yoksa)
# =========================
if ! declare -F Log >/dev/null 2>&1; then
  Log() { printf '[%(%F %T)T] [%s] %s\n' -1 "${1:-INFO}" "${*:2}"; }
fi
if ! declare -F CreateBackup >/dev/null 2>&1; then
  CreateBackup() {
    local f="${1:?}"
    [[ -f "$f" ]] && cp -a "$f" "${f}.bak-$(date +%Y%m%d-%H%M%S)" && Log INFO "Backup: $f"
  }
fi

# =========================
# Ayarlar / Varsayılanlar
# =========================
KERNEL_HARDENING_LEVEL="${KERNEL_HARDENING_LEVEL:-medium}" # basic|medium|high|paranoid
DRY_RUN="${DRY_RUN:-false}"                                # true|false
CFG="/etc/sysctl.d/99-proxmox-hardening-safe.conf"
MODS_LOAD="/etc/modules-load.d/50-bbr.conf"

# =========================
# Yardımcılar
# =========================

write_cfg_header() {
  local level="$1"
  cat >"$CFG" <<'EOF'
# ===== SAFE Proxmox Kernel Hardening =====
# Managed by: proxmox-kernel-hardening.sh
# Generated: DATE_PLACEHOLDER
# Level: LEVEL_PLACEHOLDER
EOF
  sed -i "s/DATE_PLACEHOLDER/$(date)/" "$CFG"
  sed -i "s/LEVEL_PLACEHOLDER/$level/" "$CFG"
}
append_baseline() {
  cat >>"$CFG" <<'EOF'

# ===== CRITICAL FOR PROXMOX =====
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# ===== KERNEL SECURITY (SAFE) =====
kernel.randomize_va_space = 2
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
net.core.bpf_jit_kallsyms = 0
kernel.yama.ptrace_scope = 1
kernel.perf_event_paranoid = 2
kernel.core_uses_pid = 1
kernel.ctrl-alt-del = 0
kernel.kexec_load_disabled = 0

# ===== MEMORY MANAGEMENT =====
vm.mmap_min_addr = 65536
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
vm.panic_on_oom = 0
vm.oom_kill_allocating_task = 0
vm.overcommit_memory = 0

# ===== NETWORK SECURITY =====
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1

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

# Log martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# ICMP settings
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Network performance
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 65535

# Filesystem security
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0

# PBS compatibility (keepalive)
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3
EOF
}
append_level_extras() {
  local level="$1"
  case "$level" in
  basic)
    : # baseline yeterli
    ;;
  medium)
    : # baseline yeterli
    ;;
  high)
    cat >>"$CFG" <<'EOF'

# ===== HIGH SECURITY ADDITIONS (compat-sensitive) =====
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.perf_event_paranoid = 3
net.core.bpf_jit_harden = 2
dev.tty.ldisc_autoload = 0
# AŞAĞIDAKİLERİ sadece gereksinim varsa aç:
# kernel.kexec_load_disabled = 1
# vm.swappiness = 1
# vm.overcommit_memory = 1
# vm.overcommit_ratio = 80
# kernel.unprivileged_userns_clone = 0   # unpriv LXC kullanıyorsan KAPATMA
# vm.unprivileged_userfaultfd = 0
# net.ipv4.tcp_timestamps = 0
# net.ipv4.tcp_sack = 0
EOF
    ;;
  paranoid)
    cat >>"$CFG" <<'EOF'

# ===== PARANOID MODE (USE WITH EXTREME CAUTION) =====
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 3
kernel.perf_event_paranoid = 3
kernel.unprivileged_userns_clone = 0
vm.unprivileged_userfaultfd = 0
dev.tty.ldisc_autoload = 0
# DİKKAT: Aşağıdakini açarsan reboot'a kadar yeni modül yüklenemez!
# kernel.modules_disabled = 1
EOF
    ;;
  esac
}
enable_bbr_or_cubic() {
  if modprobe tcp_bbr 2>/dev/null; then
    echo "net.ipv4.tcp_congestion_control = bbr" >>"$CFG"
    printf '%s\n' tcp_bbr >"$MODS_LOAD" # boot'ta otomatik yüklensin
    Log INFO "BBR enabled and persisted"
  else
    echo "net.ipv4.tcp_congestion_control = cubic" >>"$CFG"
    Log WARN "BBR not available; falling back to cubic"
  fi
}
apply_per_key_and_prune() {
  # Her anahtarı tek tek dener; başarısız olanı configten siler → boot’ta uyarı yok.
  Log INFO "Applying parameters one-by-one & pruning unsupported keys..."
  local TMP="/tmp/sysctl-apply.$$"
  awk -F'#' '{print $1}' "$CFG" |
    sed -n 's/^[[:space:]]*\([^[:space:]=]\+\)[[:space:]]*=[[:space:]]*\(.*\)$/\1=\2/p' >"$TMP"

  local OK=0 BAD=0
  while IFS='=' read -r key val; do
    [[ -z "${key:-}" ]] && continue
    val="$(echo "$val" | xargs)" # trim
    if sysctl -w "$key=$val" >/dev/null 2>&1; then
      ((OK++))
    else
      ((BAD++))
      key_re="$(EscapeRegex "$key")"
      # GNU sed adresinde alternatif sınırlayıcı kullanıyoruz (|). POSIX class doğru yazılmalı:
      sed -i "\|^[[:space:]]*${key_re}[[:space:]]*=|d" "$CFG"
      Log WARN "Pruned unsupported key: $key"
    fi
  done <"$TMP"
  rm -f "$TMP"
  sysctl --system >/dev/null 2>&1 || true
  Log INFO "Applied $OK keys, pruned $BAD keys"
}
verify_critical() {
  # PVE için kritik doğrulamalar
  [[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)" == "1" ]] || {
    Log ERROR "IPv4 forwarding not active; forcing on"
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
  }
  local md="$(sysctl -n kernel.modules_disabled 2>/dev/null || echo 0)"
  if [[ "$md" == "1" ]]; then
    Log ERROR "kernel.modules_disabled=1 detected! Reboot needed to recover module loads."
  fi
}
show_help() {
  cat <<'EOF'
Proxmox Kernel Hardening

Usage:
  proxmox-kernel-hardening.sh --apply [--level basic|medium|high|paranoid] [--dry-run]
  proxmox-kernel-hardening.sh --test
  proxmox-kernel-hardening.sh --revert
  proxmox-kernel-hardening.sh --help

Env:
  KERNEL_HARDENING_LEVEL=medium   # default
  DRY_RUN=false

Notes:
- 'high' ve özellikle 'paranoid' uyumluluk riski taşır. Önce test edin.
- Bu betik başarısız sysctl anahtarlarını config dosyasından otomatik siler.
EOF
}

# =========================
# Ana işlevler
# =========================
ApplyKernelHardening() {
  local LEVEL="${KERNEL_HARDENING_LEVEL:-medium}"
  Log INFO "Applying kernel hardening (level: $LEVEL, dry-run: $DRY_RUN)"

  # PVE için şart: yönlendirme açık olsun (hemen uygula)
  sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
  sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true

  if [[ "$DRY_RUN" == "true" ]]; then
    Log INFO "[DRY-RUN] Would write $CFG and apply per-key with pruning"
    return 0
  fi

  EnsureDir
  CreateBackup "/etc/sysctl.conf"

  write_cfg_header "$LEVEL"
  append_baseline
  append_level_extras "$LEVEL"
  enable_bbr_or_cubic

  # Hızlı sözdizimi validasyonu (varsa)
  if sysctl --dry-run -p "$CFG" &>/dev/null; then
    Log INFO "Syntax OK; proceeding to per-key apply"
  else
    Log WARN "sysctl --dry-run reported issues; continuing with per-key apply anyway"
  fi

  apply_per_key_and_prune
  verify_critical
  Log INFO "Kernel hardening done (level=$LEVEL). Config: $CFG"
}

# ---- drop-in replacement ----
TestKernelHardening() {
  # Renkler (TTY değilse boş)
  if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
  else
    GREEN=''
    RED=''
    YELLOW=''
    NC=''
  fi

  echo "=== Kernel Hardening Quick Test (with metrics) ==="
  local failed=0

  # Yardımcılar
  GetSysCtl() { sysctl -n "$1" 2>/dev/null || echo "unknown"; }

  #varname, value, recommended, message

  # /proc/net/netstat → TcpExt sayaçlarını çek
  read_tcpext() {
    local key="$1"
    [[ -r /proc/net/netstat ]] || {
      echo 0
      return
    }
    mapfile -t _lines < <(grep -E '^TcpExt:' /proc/net/netstat)
    if ((${#_lines[@]} >= 2)); then
      local idx=$((${#_lines[@]} - 2))
      local header="${_lines[$idx]#TcpExt: }"
      local values="${_lines[$idx + 1]#TcpExt: }"
      read -ra H <<<"$header"
      read -ra V <<<"$values"
      for i in "${!H[@]}"; do
        if [[ "${H[$i]}" == "$key" ]]; then
          echo "${V[$i]}"
          return
        fi
      done
    fi
    echo 0
  }

  # 1) Config dosyası
  local cfg="${CFG:-/etc/sysctl.d/99-proxmox-hardening-safe.conf}"
  if [[ -f "$cfg" ]]; then
    local keys
    keys=$(awk -F'#' '{print $1}' "$cfg" | sed -n 's/^[[:space:]]*\([^[:space:]=]\+\)[[:space:]]*=.*/\1/p' | wc -l)
    echo -e "${GREEN}✅ Config exists${NC}: $cfg (${keys} keys)"
  else
    echo -e "${YELLOW}⚠️  Config not found${NC}: $cfg  (uygulamak için: --apply)"
  fi

  # 2) IP forwarding (kritik)
  local fwd4 fwd6
  fwd4=$(GetSysCtl net.ipv4.ip_forward)
  fwd6=$(GetSysCtl net.ipv6.conf.all.forwarding)
  if [[ "$fwd4" == "1" ]]; then
    echo -e "${GREEN}✅ IPv4 forwarding enabled${NC}"
  else
    echo -e "${RED}❌ IPv4 forwarding disabled${NC}"
    ((failed++))
  fi
  if [[ "$fwd6" == "1" ]]; then
    echo -e "${GREEN}✅ IPv6 forwarding enabled${NC}"
  else
    echo -e "${YELLOW}⚠️  IPv6 forwarding disabled${NC}"
  fi

  # 3) Modül yükleme kilidi kontrolü
  local moddis
  moddis=$(GetSysCtl kernel.modules_disabled)
  if [[ "$moddis" == "1" ]]; then
    echo -e "${RED}❌ kernel.modules_disabled=1 (reboot gerekebilir)${NC}"
    ((failed++))
  else
    echo -e "${GREEN}✅ Module loading enabled${NC}"
  fi

  # 4) TCP congestion control & BBR modülü
  local cc
  cc=$(GetSysCtl net.ipv4.tcp_congestion_control)
  echo "ℹ️  TCP congestion control: $cc"
  if lsmod | grep -q '^tcp_bbr'; then
    echo -e "${GREEN}✅ tcp_bbr module loaded${NC}"
  else
    echo -e "${YELLOW}⚠️  tcp_bbr not loaded${NC} (cc=$cc)"
  fi

  # 5) SYN cookies ve kuyruklar
  local syncookies syn_backlog somaxconn netdev_backlog synack_retries
  syncookies=$(GetSysCtl net.ipv4.tcp_syncookies)
  syn_backlog=$(GetSysCtl net.ipv4.tcp_max_syn_backlog)
  somaxconn=$(GetSysCtl net.core.somaxconn)
  netdev_backlog=$(GetSysCtl net.core.netdev_max_backlog)
  synack_retries=$(GetSysCtl net.ipv4.tcp_synack_retries)

  if [[ "$syncookies" == "1" ]]; then
    echo -e "${GREEN}✅ TCP SYN cookies enabled${NC}"
  else
    echo -e "${YELLOW}⚠️  TCP SYN cookies not enabled${NC}"
  fi
  echo "ℹ️  tcp_max_syn_backlog=$syn_backlog, somaxconn=$somaxconn, netdev_max_backlog=$netdev_backlog, tcp_synack_retries=${synack_retries:-unknown}"
  WarnIfLowerThen tcp_max_syn_backlog "${syn_backlog//[^0-9]/}" 8192 "SYN backlog is low (but for home lab it may be fine if you want later use sysctl -w net.ipv4.tcp_max_syn_backlog=[size you want] and sysctl --system)"
  WarnIfLowerThen somaxconn "${somaxconn//[xr^0-9]/}" 32768 "Accept queue (somaxconn) is low"
  WarnIfLowerThen netdev_max_backlog "${netdev_backlog//[^0-9]/}" 4096 "NIC backlog is low"

  # 6) Kernel sayaçları (gerçekte cookie kullanımı olmuş mu?)
  local sc_sent sc_recv sc_fail
  sc_sent=$(read_tcpext SyncookiesSent)
  sc_recv=$(read_tcpext SyncookiesRecv)
  sc_fail=$(read_tcpext SyncookiesFailed)
  echo "📊 SyncookiesSent=$sc_sent, SyncookiesRecv=$sc_recv, SyncookiesFailed=$sc_fail"

  # Dinleme kuyruk taşmaları (kernel TcpExt)
  local lst_ovf lst_drop
  lst_ovf=$(read_tcpext ListenOverflows)
  lst_drop=$(read_tcpext ListenDrops)
  echo "📊 ListenOverflows=${lst_ovf:-0}, ListenDrops=${lst_drop:-0}"
  if [[ "$lst_ovf" != "0" || "$lst_drop" != "0" ]]; then
    echo -e "${YELLOW}⚠️  Backlog overflows detected — queue limits may be low${NC}"
  fi

  # 7) Dmesg’de SYN flood uyarısı var mı?
  if dmesg | grep -qi 'possible syn flooding'; then
    echo -e "${YELLOW}⚠️  Kernel reported: Possible SYN flooding${NC}"
  fi

  # 8) Dosya sistemi sertlikleri (spot check)
  for k in fs.protected_symlinks fs.protected_hardlinks fs.protected_fifos fs.protected_regular; do
    val=$(GetSysCtl "$k")
    if [[ "$val" == "1" || "$val" == "2" ]]; then
      echo -e "${GREEN}✅ $k=$val${NC}"
    else
      echo -e "${YELLOW}⚠️  $k is not enforced (=$val)${NC}"
    fi
  done

  # 9) Özet
  if ((failed == 0)); then
    echo -e "${GREEN}✅ Test passed${NC}"
    return 0
  else
    echo -e "${RED}❌ Test failed ($failed issue)${NC}"
    return 1
  fi
}
# ---- /drop-in replacement ----

RevertKernelHardening() {
  Log WARN "Reverting kernel hardening (removing $CFG, keeping backups)..."
  if [[ -f "$CFG" ]]; then
    rm -f "$CFG"
    sysctl --system >/dev/null 2>&1 || true
    Log INFO "Removed $CFG and reloaded sysctl"
  else
    Log INFO "No config to remove"
  fi
}

# =========================
# CLI
# =========================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
  --apply | apply | -a)
    shift || true
    while [[ $# -gt 0 ]]; do
      case "$1" in
      --level | -l)
        KERNEL_HARDENING_LEVEL="${2:-medium}"
        shift 2
        ;;
      --dry-run | -d)
        DRY_RUN=true
        shift
        ;;
      *) break ;;
      esac
    done
    ApplyKernelHardening
    TestKernelHardening
    ;;
  --test | test | -t)
    TestKernelHardening
    ;;
  --revert | revert | -r)
    RevertKernelHardening
    ;;
  --help | -h | help)
    show_help
    ;;
  *)
    # Argüman yoksa sadece test çalışsın (güvenli varsayılan)
    TestKernelHardening
    ;;
  esac
fi
