#!/bin/bash

IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
#set -euo pipefail
module_name="CfgCheck"
module_description="🔍 Check Proxmox datacenter.cfg for valid keys"
group="Utility"
version=1.0.0

RegisterModules "$module_name" "$module_description" "$group"
CfgCheck() {
  

CONFIG_FILE="/etc/pve/datacenter.cfg"
BACKUP_FILE="/etc/pve/datacenter.cfg.bak-$(date +%Y%m%d-%H%M%S)"
TEMP_FILE="$(mktemp)"
DRY_RUN=false

# Proxmox 8.x için bilinen geçerli anahtarlar
VALID_KEYS=(
  "keyboard"
  "console"
  "email_from"
  "fencing"
  "migration"
  "bwlimit"
  "language"
  "http_proxy"
  "mac_prefix"
  "max_workers"
  "node_policy"
  "pmg_api_url"
  "default_storage"
  "storage"
  "use_ovs"
  "dns"
  "sdn"
  "acme"
  "enable"
  "policy"
  "notify"
)

# Komut satırı argüman kontrolü
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

echo "🔍 Proxmox datacenter.cfg dosyası kontrol ediliyor..."
echo "📁 Dosya: $CONFIG_FILE"
$DRY_RUN && echo "🧪 Dry-run modunda çalışılıyor. Değişiklik yapılmayacak."

cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "💾 Yedek alındı: $BACKUP_FILE"

ERRORS=0

while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && echo "$line" >> "$TEMP_FILE" && continue

  key="${line%%:*}"
  key_trimmed="$(echo "$key" | xargs)"

  if [[ " ${VALID_KEYS[*]} " =~ " ${key_trimmed} " ]]; then
    echo "$line" >> "$TEMP_FILE"
  else
    echo "# ⛔ Geçersiz satır yorumlandı: $line" >> "$TEMP_FILE"
    echo "# $line" >> "$TEMP_FILE"
    echo "❌ Geçersiz anahtar bulundu ve yorumlandı: '$key_trimmed'"
    ERRORS=$((ERRORS+1))
  fi
done < "$CONFIG_FILE"

if $DRY_RUN; then
  echo -e "\n✅ Dry-run tamamlandı. Hiçbir dosya değiştirilmedi."
  echo "🔁 Yedek dosya mevcut: $BACKUP_FILE"
  rm -f "$TEMP_FILE"
else
  mv "$TEMP_FILE" "$CONFIG_FILE"
  echo -e "\n✅ Güncellenmiş dosya yazıldı: $CONFIG_FILE"
  echo "📦 Eski dosya yedeği: $BACKUP_FILE"
fi

if [[ "$ERRORS" -eq 0 ]]; then
  echo "🎉 Tüm satırlar geçerliydi. Dosya zaten temizdi."
fi
}