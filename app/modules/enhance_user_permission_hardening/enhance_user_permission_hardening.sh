#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="enhance_user_permission_hardening"
module_description="🛡️ enhance user permission hardening"
version=1.0.0
group="hardening"

enhance_user_permission_hardening() {
    log "INFO" "Enhancing user and permission hardening..."
    #TODO:CAN BE REMOVED IN FUTURE VERSIONS
    [ ! -d /var/log/sudo-io ] && mkdir -p /var/log/sudo-io
    [ ! -f /var/log/sudo.log ] && touch /var/log/sudo.log
    chmod 600 /var/log/sudo.log
    # Enhanced login.defs
    create_backup "/etc/login.defs"
 
    cat >/etc/login.defs <<'EOF'
# Enhanced Login Definitions Configuration

# Password aging controls
PASS_MAX_DAYS   90
PASS_MIN_DAYS   7
PASS_WARN_AGE   14
PASS_MIN_LEN    12

# User/Group ID ranges
UID_MIN         1000
UID_MAX         60000
SYS_UID_MIN     100
SYS_UID_MAX     999
GID_MIN         1000
GID_MAX         60000
SYS_GID_MIN     100
SYS_GID_MAX     999

# Home directory permissions
UMASK           027
USERGROUPS_ENAB yes
CREATE_HOME     yes

# Login restrictions
LOGIN_RETRIES   3
LOGIN_TIMEOUT   60
MOTD_FILE       /etc/motd
HUSHLOGIN_FILE  .hushlogin

# Console login
CONSOLE_GROUPS  floppy:audio:cdrom
TTYPERM         0600

# Environment
ENV_SUPATH      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV_PATH        PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games

# Mail settings
MAIL_DIR        /var/mail
MAIL_FILE       .mail

# Password encryption method
ENCRYPT_METHOD  yescrypt

# Home directory settings
DEFAULT_HOME    yes


# Chroot settings
CHFN_RESTRICT   rwh

# Subuid/subgid support
SUB_UID_MIN     100000
SUB_UID_MAX     600100000
SUB_UID_COUNT   65536
SUB_GID_MIN     100000
SUB_GID_MAX     600100000
SUB_GID_COUNT   65536
EOF
   grep -q "^ENCRYPT_METHOD" /etc/login.defs &&
        sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD yescrypt/' /etc/login.defs ||
        echo "ENCRYPT_METHOD yescrypt" >>/etc/login.defs
    # Install and configure libpam-pwquality

    apt update && apt install libpam-pwquality -y

    create_backup "/etc/pam.d/common-password"
    # password [success=1 default=ignore] pam_unix.so try_first_pass use_authtok yescrypt
    # password [success=1 default=ignore] pam_argon2.so argon2id m_cost=65536 t_cost=2 parallel=1

    # Enhanced PAM password policy
    cat >/etc/pam.d/common-password <<'EOF'
#
# /etc/pam.d/common-password - password-related modules common to all services
#
# This file is included from other service-specific PAM config files,
# and should contain a list of the password-related modules that define
# the central authentication scheme for use on the system

# Enhanced password complexity requirements
password    requisite   pam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 maxrepeat=3 maxsequence=3 maxclasschg=3 reject_username gecoscheck=1 enforce_for_root

# SHA512 encryption with high rounds
password [success=1 default=ignore] pam_unix.so obscure yescrypt

# The standard Unix authentication module
password    requisite   pam_deny.so

# Prime the stack with a positive return value.
password    required    pam_permit.so
EOF

    # Enhanced umask settings
    grep -q "pam_umask.so" /etc/pam.d/common-session || echo "session optional pam_umask.so umask=027" >>/etc/pam.d/common-session

    # Secure cron and at
    rm -f /etc/cron.deny /etc/at.deny
    touch /etc/cron.allow /etc/at.allow
    chmod 600 /etc/cron.allow /etc/at.allow
    chown root:root /etc/cron.allow /etc/at.allow
    echo "root" >/etc/cron.allow
    echo "root" >/etc/at.allow

    # Secure important file permissions
    chmod 700 /root
    chmod 600 /etc/shadow /etc/gshadow
    chmod 644 /etc/passwd /etc/group
    chmod 600 /etc/ssh/ssh_host_*
    chmod 644 /etc/ssh/ssh_host_*.pub

    # Enhanced sudo configuration
    if command -v sudo &>/dev/null; then
        create_backup "/etc/sudoers"
        cat >/etc/sudoers.d/99-hardening <<'EOF'
# Enhanced sudo security configuration
Defaults    env_reset
Defaults    mail_badpass
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults    use_pty
Defaults    log_input, log_output
Defaults    logfile="/var/log/sudo.log"
Defaults    iolog_dir="/var/log/sudo-io"
Defaults    timestamp_timeout=15
Defaults    passwd_tries=3
Defaults    passwd_timeout=5
Defaults    requiretty
Defaults    !visiblepw
Defaults    always_set_home
Defaults    match_group_by_gid
Defaults    always_query_group_plugin
EOF
        chmod 440 /etc/sudoers.d/99-hardening
    fi

    log "INFO" "User and permission hardening enhanced"
}
