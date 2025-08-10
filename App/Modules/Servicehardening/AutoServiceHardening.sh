#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="AutoServiceHardening"
module_description="🛡️ apply advanced systemd service hardening profiles"
version=2.0.0
RegisterModules $module_name $module_description $group

AutoServiceHardening() {
    Log "INFO" "Starting systemd service hardening..."

    local report="/etc/proxmox-hardening/unit-hardening-$(date +%F-%H%M%S).csv"
    mkdir -p "$(dirname "$report")"
    echo "UNIT,RESULT,PROFILE" > "$report"

    local PROFILE_STRICT PROFILE_MEDIUM PROFILE_LIGHT
    read -r -d '' PROFILE_STRICT <<'EOF'
[Service]
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadOnlyPaths=/
ReadWritePaths=/run
RestrictSUIDSGID=yes
RestrictNamespaces=yes
LockPersonality=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
EOF
    read -r -d '' PROFILE_MEDIUM <<'EOF'
[Service]
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
LockPersonality=yes
ProtectControlGroups=yes
EOF
    read -r -d '' PROFILE_LIGHT <<'EOF'
[Service]
NoNewPrivileges=yes
EOF

    declare -A ALLOW
    ALLOW["rsyslog.service"]=$'[Service]\nReadWritePaths=/var/log\n'
    ALLOW["systemd-journald.service"]=$'[Service]\nReadWritePaths=/var/log/journal\n'
    ALLOW["auditd.service"]=$'[Service]\nReadWritePaths=/var/log/audit /etc/audit\n'
    ALLOW["cron.service"]=$'[Service]\nReadWritePaths=/var/spool/cron /var/spool/anacron /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly\n'
    ALLOW["fail2ban.service"]=$'[Service]\nReadWritePaths=/var/lib/fail2ban /run/fail2ban /var/log\n'
    ALLOW["ssh.service"]=$'[Service]\nReadWritePaths=/etc/ssh /run/sshd\n'
    ALLOW["rrdcached.service"]=$'[Service]\nReadWritePaths=/var/lib/rrdcached /run/rrdcached\n'
    ALLOW["lxcfs.service"]=$'[Service]\nReadWritePaths=/var/lib/lxcfs\nPrivateTmp=yes\n'
    ALLOW["postfix.service"]=$'[Service]\nReadWritePaths=/var/spool/postfix /var/lib/postfix /etc/postfix /var/log\n'
    ALLOW["postfix@-.service"]=$'[Service]\nReadWritePaths=/var/spool/postfix /var/lib/postfix /etc/postfix /var/log\n'

    local CRITICAL_UNITS=(
      pveproxy.service pvedaemon.service pve-cluster.service pve-ha-crm.service
      pve-ha-lrm.service pvestatd.service pvescheduler.service pvefw-logger.service
      pve-firewall.service proxmox-firewall.service pve-lxc-syscalld.service
      qmeventd.service corosync.service spiceproxy.service
    )

    local DONT_TOUCH=(
      emergency.service rescue.service systemd-ask-password-console.service
      systemd-ask-password-wall.service systemd-bsod.service
    )

    write_dropin() {
        local u="$1" c="$2" n="$3"
        local dir="/etc/systemd/system/${u}.d"
        mkdir -p "$dir"
        printf '%s\n' "$c" > "${dir}/${n}"
    }

    remove_dropin() {
        local u="$1" n="$2"
        rm -f "/etc/systemd/system/${u}.d/${n}"
    }

    unit_active() { systemctl is-active -q "$1"; }

    try_profile() {
        local unit="$1" prof="$2" allow="$3"
        shift 3
        local criticals=("$@")
        local body="$prof"
        [[ -n $allow ]] && body+=$'\n'$allow

        write_dropin "$unit" "$body" "hardening.autotest.conf"
        systemctl daemon-reload

        if [[ " ${criticals[*]} " == *" $unit "* ]]; then
            mv "/etc/systemd/system/${unit}.d/hardening.autotest.conf" "/etc/systemd/system/${unit}.d/hardening.conf"
            systemctl daemon-reload
            echo "PENDING_NO_RESTART"
            return 0
        fi

        if systemctl try-restart "$unit"; then
            sleep 2
            if unit_active "$unit"; then
                mv "/etc/systemd/system/${unit}.d/hardening.autotest.conf" "/etc/systemd/system/${unit}.d/hardening.conf"
                systemctl daemon-reload
                echo "OK"
                return 0
            fi
        fi

        remove_dropin "$unit" "hardening.autotest.conf"
        systemctl daemon-reload
        return 1
    }

    local units unit load active ufs canstart allow result

    units=$(systemd-analyze security --no-pager 2>/dev/null | awk 'NR>1 && $1 ~ \.service$ {print $1}' | sort -u)

    for unit in $units; do
        for skip in "${DONT_TOUCH[@]}"; do
            [[ $unit == "$skip" ]] && continue 2
        done

        load=$(systemctl show -p LoadState --value "$unit" 2>/dev/null || true)
        active=$(systemctl show -p ActiveState --value "$unit" 2>/dev/null || true)
        ufs=$(systemctl show -p UnitFileState --value "$unit" 2>/dev/null || true)
        canstart=$(systemctl show -p CanStart --value "$unit" 2>/dev/null || true)

        if [[ "$load" != "loaded" ]]; then
            echo "$unit,SKIPPED,NOT_LOADED" >> "$report"
            continue
        fi
        if [[ "$active" != "active" && "$ufs" != "enabled" && "$canstart" == "no" ]]; then
            echo "$unit,SKIPPED,PASSIVE" >> "$report"
            continue
        fi

        allow="${ALLOW[$unit]:-}"

        if result=$(try_profile "$unit" "$PROFILE_STRICT" "$allow" "${CRITICAL_UNITS[@]}"); then
            echo "$unit,$result,STRICT" >> "$report"
            continue
        fi
        if result=$(try_profile "$unit" "$PROFILE_MEDIUM" "$allow" "${CRITICAL_UNITS[@]}"); then
            echo "$unit,$result,MEDIUM" >> "$report"
            continue
        fi
        if result=$(try_profile "$unit" "$PROFILE_LIGHT" "$allow" "${CRITICAL_UNITS[@]}"); then
            echo "$unit,$result,LIGHT" >> "$report"
            continue
        fi

        remove_dropin "$unit" "hardening.autotest.conf"
        systemctl daemon-reload
        echo "$unit,FAIL,NO_PROFILE" >> "$report"
    done

    Log "INFO" "Service hardening report: $report"
}

