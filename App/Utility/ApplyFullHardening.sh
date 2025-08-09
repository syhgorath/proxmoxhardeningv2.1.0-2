#!/bin/bash
module_name="ApplyFullHardening"
module_description="🛡️ chek system comptability"
group="hardening"
ApplyFullHardening() {
    local total_steps=${#HARDENING_STEPS[@]}
    local current_step=0

    echo -e "${GREEN}Starting comprehensive Proxmox security hardening...${NC}"

    # Initialize directories
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    touch "$LOG_FILE"

    # Check system compatibility
    check_system_compatibility

    # SSH key verification

    # Execute hardening steps
    for step_key in "${!HARDENING_STEPS[@]}"; do
        ((current_step++))

        show_progress "${HARDENING_STEPS[$step_key]}" "$current_step" "$total_steps"

        case "$step_key" in
        "ssh_config")
            echo -e "${CYAN}Configuring SSH security...${NC}"
            enhance_ssh_configuration
            ;;
        "audit_system")
            setup_advanced_auditing
            ;;
        "kernel_hardening")
            apply_kernel_hardening
            ;;
        "filesystem_security")
            configure_filesystem_security
            ;;
        "fail2ban_setup")
            setup_fail2ban_advanced
            ;;
        "proxmox_specific")
            apply_proxmox_specific_hardening
            ;;
        "file_integrity")
            setup_file_integrity_monitoring
            ;;
        "permission_hardening")
            enhance_user_permission_hardening
            ;;
        "service_hardening")
            apply_service_hardening
            ;;
        "network_security")
            # Network security is integrated into kernel hardening
            log "INFO" "Network security configured via kernel parameters"
            ;;
        "enhance_full_hardening")
            enhance_full_hardening
            ;;
        "monitoring_setup")
            setup_advanced_monitoring
            ;;
        "final_verification")
            generate_final_report
            ;;
        esac

        sleep 1 # Brief pause between steps
    done

    echo -e "\n${GREEN}✅ Proxmox security hardening completed successfully!${NC}"
    echo -e "\n${CYAN}Summary:${NC}"
    echo "• Report: $REPORT_FILE"
    echo "• Backups: $BACKUP_DIR"
    echo "• Quick check: /usr/local/bin/proxmox-security-check.sh"
    echo "• Monitoring: /usr/local/bin/security-monitor.sh"

    # Final system check
    if systemctl is-active --quiet ssh pvedaemon pveproxy; then
        log "INFO" "All critical services are running"
    else
        log "WARN" "Some critical services may not be running properly"
    fi

    # Reboot recommendation
    if [[ -f "/var/run/reboot-required" ]] || dmesg | grep -q "microcode"; then
        echo -e "\n${YELLOW}⚠️  System reboot recommended to apply all changes${NC}"
        if confirm_action "Reboot system now?" 30 "n"; then
            log "INFO" "System reboot initiated by user"
            reboot
        fi
    fi
trap cleanup INT TERM
}
