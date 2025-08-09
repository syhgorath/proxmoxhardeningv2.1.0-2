#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
# Global diziler (görünür/güncellenebilir)
declare -gA MODULE_LABEL
declare -gA MODULE_GROUP
declare -gA GROUP_INDEX
# 1) Global kayıt helper
source "$(dirname "$0")/App/Helpers/RegisterModules.sh"

# 2) Root kontrol vs.
source "$(dirname "$0")/App/Helpers/CheckRoot.sh"
CheckRoot

# 3) Autoload
source "$(dirname "$0")/Autoload.sh"
Autoload   "$(dirname "$0")/App"   # path’i net ver


# 5) Döngü
while true; do
  echo -e "${GREEN:-}========= ${SCRIPT_NAME:-HARDEN} V ${SCRIPT_VERSION:-X.Y.Z} =========${RESET:-}"
  echo "Server IP: ${IPV4:-N/A} | Public IP: ${PUBLIC_IP:-N/A}"
  echo
  Menu "MainMenu"   # Grup adını **aynı** kullan
done
