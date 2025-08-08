#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
validate_sysctl_conf() {
    local conf_file="$1"

    if [[ ! -f "$conf_file" ]]; then
        log "ERROR" "Sysctl config file not found: $conf_file"
        return 1
    fi

    log "INFO" "Validating sysctl config: $conf_file"

    local has_error=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Trim whitespace
        [[ -z "$line" || "$line" =~ ^# ]] && continue # Skip empty or comment lines

        if [[ "$line" =~ ^([a-zA-Z0-9_.-]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if ! sysctl -q -w "$key=$value" &>/dev/null; then
                log "ERROR" "Invalid sysctl key or value: $key=$value"
                has_error=1
            fi
        else
            log "ERROR" "Invalid line format in $conf_file: $line"
            has_error=1
        fi
    done < "$conf_file"

    if [[ "$has_error" -eq 0 ]]; then
        log "INFO" "Validation passed: $conf_file"
        return 0
    else
        log "ERROR" "Validation failed: $conf_file"
        return 1
    fi
}