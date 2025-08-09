#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="Helpers"
module_name="Menu"
module_description="Displays a menu for selecting and executing functions."
version=1.0.0

# Ensure required associative arrays exist when this helper is used standalone
declare -p MODULE_LABEL >/dev/null 2>&1 || declare -gA MODULE_LABEL
declare -p GROUP_INDEX >/dev/null 2>&1 || declare -gA GROUP_INDEX

Menu() {
  local group="$1"
  local i=1 key CHOICE
  declare -A INDEX_MAP
  clear

  # set -u ile güvenli kontrol
  if ! [[ -v "GROUP_INDEX[$group]" ]] || [[ -z "${GROUP_INDEX[$group]:-}" ]]; then
    echo -e "${RED:-}Bu grupta öğe yok: $group${RESET:-}"
    return 1
  fi

  IFS=' ' read -ra KEYS <<<"${GROUP_INDEX[$group]}"

  for key in "${KEYS[@]}"; do
    # Kullanılabilir etiket yoksa anahtarın kendisini göster
    local label="${MODULE_LABEL[$key]:-$key}"
    echo " [$i] $label"
    INDEX_MAP[$i]="$key"
    ((i++))
  done
  echo " [0] Çıkış"
  echo

  read -rp "Seçiminiz [0-$((i - 1))]: " CHOICE

  if [[ "$CHOICE" == "0" ]]; then
    echo -e "${YELLOW:-}👋 Çıkılıyor...${RESET:-}"
    exit 0
  elif [[ -n "${INDEX_MAP[$CHOICE]:-}" ]]; then
    local SELECTED_FUNC="${INDEX_MAP[$CHOICE]}"
    echo -e "${YELLOW:-}Çalıştırılıyor: ${MODULE_LABEL[$SELECTED_FUNC]:-$SELECTED_FUNC}${RESET:-}"

    if declare -f "$SELECTED_FUNC" >/dev/null; then
      "$SELECTED_FUNC"
    elif [[ -x "$SELECTED_FUNC" ]]; then
      bash "$SELECTED_FUNC"
    else
      echo -e "${RED:-}Fonksiyon/script bulunamadı: $SELECTED_FUNC${RESET:-}"
    fi
  else
    echo -e "${RED:-}❓ Geçersiz seçim!${RESET:-}"
  fi

  echo -e "\nDevam etmek için Enter..."
  read -r
  Menu "$group" || exit 1
}
