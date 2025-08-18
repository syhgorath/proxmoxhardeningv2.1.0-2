#!/bin/bash
# ===================== Proxmox UI Access Hardening (NPM-only default) =====================
group="hardening"
module_name="ApplyProxmoxAccessHardening"
module_description="🛡️ Proxmox UI access policy (NPM-only / IP-only / Hybrid)"
version=1.3.1
RegisterModules "$module_name" "$module_description" "$group"

ApplyProxmoxAccessHardening() {
  set -e
  Log "INFO" "Applying Proxmox access hardening..."

  # ---- MODE & VARS ----
  # MODES: npm-only | ip-only | hybrid
  MODE="${MODE:-npm-only}"
  NPM_IP="${NPM_IP:-10.1.10.6}"                    # NPM sunucunun LAN IP'si
  MGMT_NETS=(${MGMT_NETS[@]:-"10.1.10.0/24" "10.8.0.0/24"})  # SSH/cluster iç ağların
  PVE_LISTEN_IP="${PVE_LISTEN_IP:-}"               # tek node ise isteğe bağlı
  CIPHERS_12="ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
  CIPHERS_13="TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
  TS="$(date +%F-%H%M%S)"

  case "$MODE" in
    npm-only|hybrid) [ -n "$NPM_IP" ] || { Log "ERROR" "NPM_IP required for $MODE"; return 1; } ;;
    ip-only) : ;;
    *) Log "ERROR" "Unknown MODE '$MODE'"; return 1 ;;
  esac

  # ---- datacenter.cfg ----
  mkdir -p /etc/pve
  DC="/etc/pve/datacenter.cfg"; [ -f "$DC" ] && cp -a "$DC" "${DC}.bak.${TS}"; touch "$DC"
  set_dc_opt(){ local k="$1" v="$2"; grep -qE "^${k}:" "$DC" && sed -i "s|^${k}:.*|${k}: ${v}|" "$DC" || printf "%s: %s\n" "$k" "$v" >>"$DC"; }
  set_dc_opt keyboard "tr"
  set_dc_opt console  "xtermjs"
  set_dc_opt email_from "root@proxmox"
  # set_dc_opt migration "secure,network=10.1.10.0/24"

  # ---- Proxmox Firewall (cluster.fw) ----
  mkdir -p /etc/pve/firewall
  CF="/etc/pve/firewall/cluster.fw"; cp -a "$CF" "${CF}.bak.${TS}" 2>/dev/null || true
  {
    echo "[OPTIONS]"; echo "enable: 1"; echo "ebtables: 1"; echo "policy_in: DROP"; echo "policy_out: ACCEPT"; echo
    echo "[IPSET management_nets]"; printf "%s\n" "${MGMT_NETS[@]}"; echo
    if [[ "$MODE" != "ip-only" ]]; then echo "[IPSET reverse_proxy]"; echo "${NPM_IP}"; echo; fi
    echo "[group secure_access]"
    case "$MODE" in
      npm-only)
        echo "IN ACCEPT -p tcp -dport 8006 -source +reverse_proxy"
        echo "IN ACCEPT -p tcp -dport 3128 -source +reverse_proxy   # (opsiyonel) SPICE"
        ;;
      ip-only)
        echo "IN ACCEPT -p tcp -dport 8006 -source +management_nets"
        ;;
      hybrid)
        echo "IN ACCEPT -p tcp -dport 8006 -source +reverse_proxy"
        echo "IN ACCEPT -p tcp -dport 8006 -source +management_nets"
        echo "IN ACCEPT -p tcp -dport 3128 -source +reverse_proxy   # (opsiyonel)"
        ;;
    esac
    echo "IN ACCEPT -p tcp -dport 22   -source +management_nets   # SSH"
         
    echo "IN ACCEPT -p udp -dport 5404:5405 -source +management_nets  # Corosync"; echo
    echo "[RULES]"; echo "GROUP secure_access"; echo "IN ACCEPT -i lo"; echo "IN ACCEPT -p icmp"; echo "IN REJECT"
  } >"$CF"

  # ---- Node local firewall (host.fw) ----
  HF="/etc/pve/local/host.fw"; cp -a "$HF" "${HF}.bak.${TS}" 2>/dev/null || true
  {
    echo "[OPTIONS]"; echo "enable: 1"; echo "Log_level_in: info"; echo "Log_level_out: info"; echo
    echo "[RULES]"; echo "IN ACCEPT -i lo"; echo "IN ACCEPT -p icmp -icmp-type echo-request"
    case "$MODE" in
      npm-only) echo "IN ACCEPT -p tcp -dport 8006 -source ${NPM_IP}"; echo "IN ACCEPT -p tcp -dport 3128 -source ${NPM_IP}   # (opsiyonel)";;
      ip-only)  echo "IN ACCEPT -p tcp -dport 8006 -source +management_nets";;
      hybrid)   echo "IN ACCEPT -p tcp -dport 8006 -source ${NPM_IP}"; echo "IN ACCEPT -p tcp -dport 8006 -source +management_nets"; echo "IN ACCEPT -p tcp -dport 3128 -source ${NPM_IP}   # (opsiyonel)";;
    esac
    echo "IN ACCEPT -p tcp -dport 22   -source +management_nets"
    echo "IN ACCEPT -p udp -dport 5404:5405 -source +management_nets"
    echo "IN REJECT"
  } >"$HF"

  # ---- /etc/default/pveproxy ----
  DEF="/etc/default/pveproxy"; [ -f "$DEF" ] && CreateBackup "$DEF" || true
  mkdir -p /var/log/pveproxy; chown www-data:adm /var/log/pveproxy 2>/dev/null || true
  join_by_comma(){ local IFS=,; echo "$*"; }
  case "$MODE" in
    npm-only) ALLOW="${NPM_IP}";;
    ip-only)  ALLOW="$(join_by_comma "${MGMT_NETS[@]}")";;
    hybrid)   ALLOW="$(printf "%s,%s" "$NPM_IP" "$(join_by_comma "${MGMT_NETS[@]}")")";;
  esac
  {
    echo "# Managed by hardening script ${TS}"
    echo "ALLOW_FROM=\"${ALLOW}\""
    echo "DENY_FROM=\"all\""
    echo "POLICY=\"allow\""
    [[ -n "$PVE_LISTEN_IP" ]] && echo "LISTEN_IP=\"${PVE_LISTEN_IP}\""
    echo "CIPHERS=\"${CIPHERS_12}\""
    echo "CIPHERSUITES=\"${CIPHERS_13}\""
    if [[ "$MODE" != "ip-only" ]]; then
      echo 'PROXY_REAL_IP_HEADER="X-Forwarded-For"'
      echo "PROXY_REAL_IP_ALLOW_FROM=\"${NPM_IP}\""
    fi
  } >"$DEF"

  # ---- Firewall & servisler ----
  if command -v pve-firewall &>/dev/null; then
    systemctl enable pve-firewall
    systemctl restart pve-firewall
    pve-firewall compile
  fi
  systemctl restart pvedaemon
  systemctl restart pveproxy
  systemctl restart spiceproxy 2>/dev/null || true

  Log "INFO" "Proxmox access hardening applied (MODE=${MODE})"
}
normalize_cidrs() {
  # Bozuk IFS/tek-string/v|rgül/boşluk ayırmalarını satıra çevir
  # örn: "10.1.10.0/24 10.8.0.0/24" veya "10.1.10.0/24,10.8.0.0/24"
  # çıktıyı: iki ayrı satır yapar
  local raw="$*"
  printf '%s\n' "$raw" | tr ',;' '\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g;/^$/d'
}
# ===================== UI Shell Güvencesi (termproxy SUID) =====================
module_name="EnsureTermproxySuid"
module_description="🧰 Ensure proxmox-termproxy has setuid root and /dev/pts is mounted"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"

EnsureTermproxySuid() {
  set -e
  local TP="/usr/libexec/proxmox/proxmox-termproxy"
  if [ -x "$TP" ]; then
    chown root:root "$TP"
    chmod 4755 "$TP"    # -rwsr-xr-x
  fi
  mount | grep -q 'type devpts' || mount -t devpts devpts /dev/pts || true
  Log "INFO" "termproxy SUID ensured; devpts ok."
}
# ===================== Proxmox-specific Hardening (PVE) =====================
#proxy_set_header Host $host;
#proxy_set_header X-Forwarded-Proto $scheme;
#proxy_set_header Upgrade $http_upgrade;
#proxy_set_header Connection $connection_upgrade;
#proxy_http_version 1.1;
#proxy_ssl_server_name on;
#proxy_ssl_verify off; 