#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
 module_name="run_rkhunter_check"
    module_description="🛡️ run rkhunter check"
    version=1.0.0
   group="hardening"
run_rkhunter_check(){
   
  

    # Create a script to run rkhunter checks
  cat >/usr/local/bin/check_rkhunter.sh <<'EOF'

# === CONFIGURATION ===
readonly LOG_DIR="/var/log/rkhunter"
readonly LOG_FILE="${LOG_DIR}/rkhunter_$(date +%Y%m%d_%H%M%S).log"
readonly CLEAN_MARKER="${LOG_DIR}/.last_clean"
readonly EMAIL_REPORT="root@localhost"  # Mail atmak istersen
readonly RKHUNTER_BIN="/usr/bin/rkhunter"

# === PREPARATION ===
mkdir -p "$LOG_DIR"

# === LOG FUNCTION ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# === START ===
log "Starting rkhunter check..."

# === CHECK SYSTEM ===
"$RKHUNTER_BIN" --versioncheck >> "$LOG_FILE" 2>&1
"$RKHUNTER_BIN" --update >> "$LOG_FILE" 2>&1

# === PERFORM CHECK ===
"$RKHUNTER_BIN" --check --rwo --sk >> "$LOG_FILE" 2>&1

# === ANALYZE RESULTS ===
if grep -qEi 'Warning|infected|suspect|rootkit' "$LOG_FILE"; then
    log "❌ Uyarılar bulundu! --propupd yapılmadı."
    log "Log dosyası: $LOG_FILE"
    echo "RKHunter WARNING Detected on $(hostname) at $(date)" | mail -s "RKHunter WARNING" "$EMAIL_REPORT"
else
    log "✅ Her şey temiz görünüyor, güncelleniyor..."
    "$RKHUNTER_BIN" --propupd >> "$LOG_FILE" 2>&1
    touch "$CLEAN_MARKER"
    log "✔️ Propupd başarıyla güncellendi."
fi

log "RKHunter taraması tamamlandı."

EOF
}