#!/bin/bash
module_name="ApplyFullHardening"
module_description="🚀  Comprehensive Proxmox security hardening script"
group="MainMenu"
version=1.0.0
RegisterModules $module_name $module_description $group
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

    echo -e "\n${GREEN}✅ Proxmox security hardening completed successfully!${RESET}"
    echo -e "\n${CYAN}Summary:${RESET}"
    echo "• Report: $REPORT_FILE"
    echo "• Backups: $BACKUP_DIR"
    echo "• Quick check: /usr/local/bin/proxmox-security-check.sh"
    echo "• Monitoring: /usr/local/bin/security-monitor.sh"

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
