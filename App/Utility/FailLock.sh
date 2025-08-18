#!/bin/bash
module_name="FailLock"
module_description="🔒 Configure faillock for account lockout"
group="hardening"
version=1.1.0

RegisterModules "$module_name" "$module_description" "$group"

FailLock() {
  set -euo pipefail
  Log "INFO" "Starting faillock configuration..."

  # --- PREP & BACKUP ---------------------------------------------------------
  install -d -m0755 /var/log/faillock
  install -d -m0755 /etc/security
  TS="$(date +%F-%H%M%S)"

  for f in /etc/pam.d/common-auth /etc/pam.d/common-account; do
    if [ -f "$f" ]; then
      cp -a "$f" "${f}.bak.${TS}"
      Log "INFO" "Backup: ${f}.bak.${TS}"
    fi
  done

  # --- /etc/security/faillock.conf -------------------------------------------
  tee /etc/security/faillock.conf >/dev/null <<'EOF'
# managed by hardening script
deny = 5
unlock_time = 900
fail_interval = 900
audit
# Optional (harden more; commented by default)
# even_deny_root
# root_unlock_time = 900
EOF

  # --- COMMON-AUTH: clean & write minimal, correct order ----------------------
  # 1) Remove every previous faillock line to avoid duplicates/loops
  if [ -f /etc/pam.d/common-auth ]; then
    sed -i '/pam_faillock\.so/d' /etc/pam.d/common-auth
  fi

  # 2) Replace file with a safe, minimal baseline (faillock included)
  #    This layout prevents double prompts and weird loops.
  tee /etc/pam.d/common-auth >/dev/null <<'EOF'
# /etc/pam.d/common-auth (managed by hardening script)
# Minimal, robust ordering with pam_faillock
# - pam_unix first (short-circuit on success)
# - faillock authfail then authsucc
# - sane fallbacks

auth    [success=1 default=bad] pam_unix.so nullok
auth    [default=die]           pam_faillock.so authfail
auth    sufficient              pam_faillock.so authsucc

auth    requisite               pam_deny.so
auth    required                pam_permit.so
EOF

  # --- COMMON-ACCOUNT: ensure faillock account hook exists --------------------
  if ! grep -q 'pam_faillock\.so' /etc/pam.d/common-account 2>/dev/null; then
    # insert at top (keep rest of file intact)
    sed -i '1i account required pam_faillock.so' /etc/pam.d/common-account || {
      # if file missing or sed failed, create a minimal one
      tee /etc/pam.d/common-account >/dev/null <<'EOACC'
# /etc/pam.d/common-account (managed by hardening script)
account required pam_unix.so
account required pam_faillock.so
EOACC
    }
  fi

  # --- RESET LOCKS (so you don't get stuck) ----------------------------------
  if command -v faillock >/dev/null 2>&1; then
    # reset for common accounts you use; adjust as needed
    for u in root syhgorath; do
      faillock --user "$u" --reset || true
    done
  elif command -v pam_tally2 >/dev/null 2>&1; then
    for u in root syhgorath; do
      pam_tally2 --user "$u" --reset || true
    done
  fi

  Log "INFO" "faillock configured. Test console/SSH login and sudo now."
}

# (optional) small self-check helper you might call from your framework
FailLock_SelfCheck() {
  echo "== faillock.conf =="
  sed -n '1,80p' /etc/security/faillock.conf || true
  echo "== common-auth =="
  sed -n '1,80p' /etc/pam.d/common-auth || true
  echo "== common-account =="
  sed -n '1,80p' /etc/pam.d/common-account || true
}
