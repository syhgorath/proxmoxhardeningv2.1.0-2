#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="Utility"
module_name="ManageBackups"
module_description="💾 manage backup script"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"

ManageBackups() {
    echo -e "${CYAN}════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}              BACKUP MANAGEMENT               ${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════${RESET}"

    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "\n${GREEN}Available Backups:${RESET}"
        ls -la "$BACKUP_DIR"

        echo -e "\n${GREEN}Backup Statistics:${RESET}"
        echo "Total backups: $(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)"
        echo "Total size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
        echo "Oldest backup: $(ls -lt "$BACKUP_DIR" 2>/dev/null | tail -1 | awk '{print $6, $7, $8}')"
        echo "Newest backup: $(ls -lt "$BACKUP_DIR" 2>/dev/null | head -2 | tail -1 | awk '{print $6, $7, $8}')"

        if ConfirmAction "Clean old backups (>30 days)?" 15 "n"; then
            find "$BACKUP_DIR" -type f -mtime +30 -delete
            echo "Old backups cleaned"
        fi
    else
        echo -e "${YELLOW}No backups directory found${RESET}"
    fi
}
