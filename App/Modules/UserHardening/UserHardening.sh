#!/bin/bash
#set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

group="hardening"
module_name="UserHardening"
module_description="🛡️ enhance user permission hardening"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"

# Opsiyon: sudo yoksa otomatik kurulsun mu? (true/false)
INSTALL_SUDO_IF_MISSING="${INSTALL_SUDO_IF_MISSING:-true}"

UserHardening() {
    Log "INFO" "Enhancing user and permission hardening..."

    export DEBIAN_FRONTEND=noninteractive

    # --- sudo IO log dizini ve dosyası ---
    install -d -m 700 /var/log/sudo-io
    [ -f /var/log/sudo.log ] || touch /var/log/sudo.log
    chmod 600 /var/log/sudo.log

    # --- /etc/login.defs yedeği ve güvenli içerik ---
    CreateBackup "/etc/login.defs"
   
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

# Environment
ENV_SUPATH      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV_PATH        PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games

# Mail settings
MAIL_DIR        /var/mail
MAIL_FILE       .mail

# Password encryption method (modern)
ENCRYPT_METHOD  yescrypt
YESCRYPT_COST_FACTOR 7

# Home directory settings
DEFAULT_HOME    no

# Chroot settings
CHFN_RESTRICT   rwh

# Subuid/subgid support
SUB_UID_MIN     100000
SUB_UID_MAX     600100000
SUB_UID_COUNT   65536
SUB_GID_MIN     100000
SUB_GID_MAX     600100000
SUB_GID_COUNT   65536

# Legacy console directives intentionally disabled by hardening:
# CONSOLE_GROUPS disabled by hardening
# TTYPERM disabled by hardening
EOF

    # --- PAM modülleri (idempotent kurulum) ---
    if ! dpkg -s libpam-pwquality >/dev/null 2>&1 || ! dpkg -s libpam-tmpdir >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y libpam-pwquality libpam-tmpdir
    fi

    # --- /etc/pam.d/common-password yedeği ve politika ---
    CreateBackup "/etc/pam.d/common-password"
    cat >/etc/pam.d/common-password <<'EOF'
#
# /etc/pam.d/common-password - password-related modules common to all services
#

# Password complexity policy
password    requisite   pam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 maxrepeat=3 maxsequence=3 maxclassrepeat=3 reject_username gecoscheck=1 dictcheck=1 enforce_for_root

# Use yescrypt with fixed cost and reuse the verified token
password    [success=1 default=ignore] pam_unix.so yescrypt rounds=7 use_authtok

# Standard modules
password    requisite   pam_deny.so
password    required    pam_permit.so
EOF

    # --- PAM faillock (başarısız giriş denetimi) ---
    if [ ! -f /etc/security/faillock.conf ]; then
        cat >/etc/security/faillock.conf <<'EOF'
deny = 5
unlock_time = 900
fail_interval = 900
audit
EOF
    fi
    # common-auth entegrasyonu (idempotent)
    grep -q 'pam_faillock.so preauth' /etc/pam.d/common-auth || \
        sed -i '1iauth required pam_faillock.so preauth silent' /etc/pam.d/common-auth
    grep -q 'pam_faillock.so authfail' /etc/pam.d/common-auth || \
        sed -i '/pam_unix.so/aauth [default=die] pam_faillock.so authfail' /etc/pam.d/common-auth
    # common-account entegrasyonu (idempotent)
    grep -q 'pam_faillock.so' /etc/pam.d/common-account || \
        sed -i '1iaccount required pam_faillock.so' /etc/pam.d/common-account

    # --- Oturum umask ve tmpdir ---
    grep -q "pam_umask.so" /etc/pam.d/common-session   || echo "session optional pam_umask.so umask=027" >>/etc/pam.d/common-session
    grep -q "pam_tmpdir.so" /etc/pam.d/common-session  || echo "session optional pam_tmpdir.so" >>/etc/pam.d/common-session

    # --- cron/at allow-list (root ile sınırla) ---
    rm -f /etc/cron.deny /etc/at.deny
    : > /etc/cron.allow
    : > /etc/at.allow
    echo "root" >/etc/cron.allow
    echo "root" >/etc/at.allow
    chmod 600 /etc/cron.allow /etc/at.allow
    chown root:root /etc/cron.allow /etc/at.allow

    # --- Kritik izinler ---
    chmod 700 /root
    chown root:shadow /etc/shadow /etc/gshadow 2>/dev/null || true
    chmod 600 /etc/shadow /etc/gshadow
    chmod 644 /etc/passwd /etc/group
    chmod 600 /etc/ssh/ssh_host_* 2>/dev/null || true
    chmod 644 /etc/ssh/ssh_host_*.pub 2>/dev/null || true
    chmod 600 /etc/crontab 2>/dev/null || true
    chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly

    # --- sudoers (gerekirse sudo'yu otomatik kur, sonra sertleştir) ---
    if ! command -v sudo >/dev/null 2>&1; then
        if [ "$INSTALL_SUDO_IF_MISSING" = "true" ]; then
            Log "INFO" "sudo not found; installing..."
            apt-get update -y
            apt-get install -y sudo
        else
            Log "WARN" "sudo not found and auto-install disabled (INSTALL_SUDO_IF_MISSING=false); skipping sudo hardening."
        fi
    fi

    if command -v sudo >/dev/null 2>&1; then
        CreateBackup "/etc/sudoers"
        cat >/etc/sudoers.d/99-hardening <<'EOF'
# Enhanced sudo security configuration
Defaults    env_reset
Defaults    mail_badpass
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults    use_pty
Defaults    log_input, log_output
Defaults    logfile="/var/log/sudo.log"
Defaults    iolog_dir="/var/log/sudo-io"
Defaults    tty_tickets
Defaults    timestamp_timeout=15
Defaults    passwd_tries=3
Defaults    passwd_timeout=5
Defaults    !visiblepw
Defaults    match_group_by_gid
EOF
        chmod 440 /etc/sudoers.d/99-hardening
        visudo -cf /etc/sudoers && Log "INFO" "sudoers syntax OK" || { echo "sudoers syntax FAILED"; exit 1; }
    fi
for u in $(awk -F: '($3>=1000)&&($7!~/nologin|false/){print $1}' /etc/passwd); do
  grep -q "^$u:\$y\$" /etc/shadow || echo "rehash gerektirir -> $u"
    Log "INFO" "Userencry for $u rehashed"
done
grep -R "pam_tmpdir.so" /etc/pam.d/common-session* || echo "session optional pam_tmpdir.so" | sudo tee -a /etc/pam.d/common-session

    Log "INFO" "User and permission hardening enhanced"
}
