#!/bin/bash
module_name="ApplyFullHardening"
module_description="🚀  Comprehensive Proxmox security hardening script"
group="MainMenu"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"
ApplyFullHardening() {
    IFS=' ' read -ra HARDENING_STEPS <<<"${GROUP_INDEX['hardening']}"
    local total_steps=${#HARDENING_STEPS[@]}
    local current_step=0

    echo -e "${GREEN}Starting comprehensive Proxmox security hardening...${RESET}"

    # Initialize directories
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    touch "$LOG_FILE"

    # Check system compatibility
    CheckSystemCompatibility

    # SSH key verification

    # Execute hardening steps
    for step_key in "${!HARDENING_STEPS[@]}"; do
        ((current_step++))

        ShowProgress "${HARDENING_STEPS[$step_key]}" "$current_step" "$total_steps"

        echo -e "${RESET}"
        echo -e "${CYAN}Executing step $current_step/${total_steps}: ${HARDENING_STEPS[$step_key]}...${RESET}"
        Log "INFO" "Executing step $current_step/${total_steps}: ${HARDENING_STEPS[$step_key]}"
        ${HARDENING_STEPS[$step_key]} || {
            echo -e "${RED}❌ Step failed: ${HARDENING_STEPS[$step_key]}${RESET}"
            Log "ERROR" "Step failed: ${HARDENING_STEPS[$step_key]}"
            continue
        }

        sleep 1 # Brief pause between steps
    done
    postconf -e 'smtpd_banner=$myhostname ESMTP'
    postconf -e 'smtpd_helo_required=yes'
    postconf -e 'disable_vrfy_command=yes'
    systemctl reload postfix
    tee /etc/issue >/dev/null <<'EOF'
Authorized access only. Unauthorized use may be monitored and reported.
EOF
    cp /etc/issue /etc/issue.net

    echo -e "\n${GREEN}✅ Proxmox security hardening completed successfully!${RESET}"
    echo -e "\n${CYAN}Summary:${RESET}"
    echo "• Report: $REPORT_FILE"
    echo "• Backups: $BACKUP_DIR"
    echo "• Quick check: /usr/local/bin/proxmox-security-check.sh"
    echo "• Monitoring: /usr/local/bin/security-monitor.sh"
    systemctl get-default
    # headless için öneri:
# --- SAFE REPLACEMENT (drop-in) ---

# Varsayılan hedef (GUI’siz hostlar için normal): değiştirmek istemiyorsan yorumla
systemctl set-default multi-user.target

# Önce çalıştığın ağa göre temel ağ servisini koru
KEEP=( ssh.service pvedaemon.service pveproxy.service pve-cluster.service pvestatd.service pvescheduler.service qmeventd.service pve-guests.service )

# Proxmox firewall bileşenleri (kullanıyorsan koru)
for s in proxmox-firewall.service pve-firewall.service pve-firewall-commit.service pvefw-logger.service; do
  systemctl list-unit-files | grep -q "^$s" && KEEP+=("$s")
done

# Ağ: ifupdown2 (networking) veya systemd-networkd hangisi varsa onu koru
systemctl list-unit-files | grep -q '^networking.service'            && KEEP+=( networking.service )
systemctl list-unit-files | grep -q '^systemd-networkd.service'      && KEEP+=( systemd-networkd.service systemd-networkd-wait-online.service )

# Zaman senkronu: chrony ya da timesyncd
systemctl list-unit-files | grep -q '^chrony.service'                 && KEEP+=( chrony.service )
systemctl list-unit-files | grep -q '^systemd-timesyncd.service'      && KEEP+=( systemd-timesyncd.service )

# Log & Audit & MAC
systemctl list-unit-files | grep -q '^rsyslog.service'                && KEEP+=( rsyslog.service )
systemctl list-unit-files | grep -q '^auditd.service'                 && KEEP+=( auditd.service )
systemctl list-unit-files | grep -q '^apparmor.service'               && KEEP+=( apparmor.service )

# Opsiyonel ama yaygın korumalar
for s in fail2ban.service usbguard.service smartmontools.service lvm2-monitor.service e2scrub_reap.service; do
  systemctl list-unit-files | grep -q "^$s" && KEEP+=("$s")
done

# ZFS kullanıyorsan kritik servisleri koru
if command -v zpool >/dev/null 2>&1; then
  for s in zfs-import-cache.service zfs-mount.service zfs-zed.service; do
    systemctl list-unit-files | grep -q "^$s" && KEEP+=("$s")
  done
fi

# DRY-RUN ile önce göster (true/false)
DRY_RUN="${DRY_RUN:-true}"

# Whitelist'i regex'e çevir
KEEP_RE=$(printf '%s\n' "${KEEP[@]}" | sed 's/[.[\*^$]/\\&/g' | paste -sd'|' -)

# Sadece gerçekten enabled olan service’leri al ve whitelist’te olmayanları devre dışı bırak
while read -r svc state; do
  [[ "$state" != "enabled" ]] && continue
  if [[ "$svc" =~ ^($KEEP_RE)$ ]]; then
    Log "INFO" "Kept essential service: $svc"
  else
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY-RUN] Would disable: $svc"
    else
      systemctl disable "$svc"
      Log "INFO" "Disabled NON-WHITELIST service: $svc"
    fi
  fi
done < <(systemctl list-unit-files --type=service --state=enabled)

    groupadd -f buildlock
# gcc/make/ld/as gibi başlıcaları kısıtla (DPKG kalıcı override)
for bin in /usr/bin/gcc /usr/bin/make /usr/bin/ld /usr/bin/as; do
  if [ -x "$bin" ]; then
    dpkg-statoverride --update --add root buildlock 0750 "$bin"
  fi
done
# geri almak için:
# dpkg-statoverride --remove /usr/bin/gcc  (diğerlerine de aynı)
    # Final system check
    if systemctl is-active --quiet ssh pvedaemon pveproxy; then
        Log "INFO" "All critical services are running"
    else
        Log "WARN" "Some critical services may not be running properly"
    fi

    # Reboot recommendation
    if [[ -f "/var/run/reboot-required" ]] || dmesg | grep -q "microcode"; then
        echo -e "\n${YELLOW}⚠️  System reboot recommended to apply all changes${RESET}"
        if ConfirmAction "Reboot system now?" 30 "n"; then
            Log "INFO" "System reboot initiated by user"
            reboot
        fi
    fi
    trap cleanup INT TERM
}
