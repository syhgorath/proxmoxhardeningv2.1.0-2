#!/bin/bash
#set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="Utility"
module_name="RunRkHunter"
module_description="🛡️ run rkhunter check"
version=1.0.0
RegisterModules $module_name $module_description $group
RunRkHunter() {

    # Create a script to run rkhunter checks
    cat >/usr/local/bin/check_rkhunter.sh <<'EOF'

# === CONFIGURATION ===
readonly Log_DIR="/var/log/rkhunter"
readonly LOG_FILE="${Log_DIR}/rkhunter_$(date +%Y%m%d_%H%M%S).log"
readonly CLEAN_MARKER="${Log_DIR}/.last_clean"
readonly EMAIL_REPORT="root@localhost"  # Mail atmak istersen
readonly RKHUNTER_BIN="/usr/bin/rkhunter"

# === PREPARATION ===
mkdir -p "$Log_DIR"

# === Log FUNCTION ===
Log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# === START ===
Log "Starting rkhunter check..."

# === CHECK SYSTEM ===
"$RKHUNTER_BIN" --versioncheck >> "$LOG_FILE" 2>&1
"$RKHUNTER_BIN" --update >> "$LOG_FILE" 2>&1

# === PERFORM CHECK ===
"$RKHUNTER_BIN" --check --rwo --sk >> "$LOG_FILE" 2>&1

# === ANALYZE RESULTS ===
if grep -qEi 'Warning|infected|suspect|rootkit' "$LOG_FILE"; then
    Log "❌ Uyarılar bulundu! --propupd yapılmadı."
    Log "Log dosyası: $LOG_FILE"
    echo "RKHunter WARNING Detected on $(hostname) at $(date)" | mail -s "RKHunter WARNING" "$EMAIL_REPORT"
else
    Log "✅ Her şey temiz görünüyor, güncelleniyor..."
    "$RKHUNTER_BIN" --propupd >> "$LOG_FILE" 2>&1
    touch "$CLEAN_MARKER"
    Log "✔️ Propupd başarıyla güncellendi."
fi

Log "RKHunter taraması tamamlandı."

EOF
}
