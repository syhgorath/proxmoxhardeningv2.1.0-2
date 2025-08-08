#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
#set -u -o pipefail
declare -A MENU_ITEMS_SOURCE=()
declare -A HARDEN_ITEMS_SOURCE=()
source "$(dirname "$0")/definitions.cfg" 1 || exit 1
source "$(dirname "$0")/autoload.sh" 1 || exit 1

autoload   "app" || exit 1
while true; do
    echo -e "${GREEN}========= ${SCRIPT_NAME} V ${SCRIPT_VERSION} =========${RESET}"
    echo "Server IP: $IPV4 | Public IP: $PUBLIC_IP"
    echo
    i=1
    declare -A INDEX_MAP
    for key in "${!MENU_ITEMS_SOURCE[@]}"; do
        echo " [$i] ${MENU_ITEMS_SOURCE[$key]}"
        INDEX_MAP[$i]="$key"
        ((i++))
    done
    echo " [0] Exit"
    echo
    read -rp "Select an option [0-$((i-1))]: " CHOICE

    if [[ "$CHOICE" == "0" ]]; then
        echo -e "${YELLOW}Exiting...${RESET}"
        exit 0
    elif [[ -n "${INDEX_MAP[$CHOICE]}" ]]; then
        SELECTED_FUNC="${INDEX_MAP[$CHOICE]}"
        if declare -f "$SELECTED_FUNC" >/dev/null; then
            echo -e "${YELLOW}Executing: ${MENU_ITEMS_SOURCE[$SELECTED_FUNC]}...${RESET}"
            "$SELECTED_FUNC"
        elif [[ -x "$SELECTED_FUNC" ]]; then
            echo -e "${YELLOW}Running script: $SELECTED_FUNC...${RESET}"
            bash "$SELECTED_FUNC"
        else
            echo -e "${RED}Function or script not found: $SELECTED_FUNC${RESET}"
        fi
    else
        echo -e "${RED}Invalid option! Please select a valid number.${RESET}"
    fi

    echo -e "\nPress Enter to return to menu..."
    read -r
    clear
done