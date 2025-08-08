#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

# Proxmox datacenter.cfg geçerli anahtar listesi (Proxmox 8.x için)
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

CONFIG_FILE="/etc/pve/datacenter.cfg"

echo "🔍 Geçersiz satırlar kontrol ediliyor: $CONFIG_FILE"
echo "--------------------------------------------"

ERROR_FOUND=0

while IFS= read -r line; do
  # Yorum ve boş satırları atla
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  key="${line%%:*}"
  key_trimmed="$(echo "$key" | xargs)" # boşlukları temizle

  # Eğer key geçerli değilse uyar
  if [[ ! " ${VALID_KEYS[*]} " =~ " ${key_trimmed} " ]]; then
    echo "❌ Geçersiz anahtar bulundu: '$key_trimmed'"
    echo "    Satır: $line"
    ERROR_FOUND=1
  fi
done < "$CONFIG_FILE"

if [[ "$ERROR_FOUND" -eq 0 ]]; then
  echo "✅ Tüm satırlar geçerli."
else
  echo -e "\n⚠️ Yukarıdaki satırlar schema tarafından tanınmıyor. Yorum satırı (#) yapman veya silmen önerilir."
fi