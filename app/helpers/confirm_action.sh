#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    local response=""

    # Varsayılan seçimi belirle
    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
        default_choice="Y"
    else
        prompt="[y/N]"
        default_choice="N"
    fi

    # Renkli ve bold mesaj
    echo -e "${BOLD_YELLOW} SORU:${RESET} $message"
    while true; do
        read -p "$prompt " -n 1 -r response
        echo  # Yeni satır

        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            "" ) 
                if [[ "$default_choice" == "Y" ]]; then 
                    return 0
                else 
                    return 1
                fi
                ;;
            * ) 
                echo -e "${BOLD_RED}  Please! ${RESET}  type Y (Yes) veya N (No)."
                ;;
        esac
    done
}