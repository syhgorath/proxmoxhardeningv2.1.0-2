#!/bin/bash
module_name="FailLock"
module_description="🔒 Configure faillock for account lockout"
group="hardening"
version=1.0.0
RegisterModules $module_name $module_description $group
FailLock() {
    Log "INFO" "Starting faillock configuration..."

    # Create directories if they do not exist
    install -d -m0755 /var/log/faillock
    install -d -m0755 /etc/security

    tee /etc/security/faillock.conf >/dev/null <<'EOF'
deny = 5
unlock_time = 900
fail_interval = 900
audit

EOF
    # common-auth: preauth ve authfail kancaları
    grep -q 'pam_faillock.so preauth' /etc/pam.d/common-auth ||
        sed -i '1iauth required pam_faillock.so preauth silent' /etc/pam.d/common-auth

    grep -q 'pam_faillock.so authfail' /etc/pam.d/common-auth ||
        sed -i '/pam_unix.so/aauth [default=die] pam_faillock.so authfail' /etc/pam.d/common-auth

    # common-account: hesap kancası
    grep -q 'pam_faillock.so' /etc/pam.d/common-account ||
        sed -i '1iaccount required pam_faillock.so' /etc/pam.d/common-account
    sed -i '1iauth [default=die] pam_faillock.so authfail' /etc/pam.d/common-auth
    sed -i '1i# faillock added' /etc/pam.d/common-auth
    sed -i '/pam_unix.so/ i auth [success=1 default=bad] pam_faillock.so authsucc' /etc/pam.d/common-auth
    sed -i '1 iaccount required pam_faillock.so' /etc/pam.d/common-account
}
