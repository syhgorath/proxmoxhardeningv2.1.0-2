#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

autoload() {

  local path="$1"

  for item in "$path"/*.sh; do
    # Sembolik linkleri atla (isteğe bağlı)
    [ -L "$item" ] && continue

    if [ -f "$item" ]; then
      # Geçici değişkenleri temizle
      unset menu_name menu_description 2>/dev/null
  
      # Dosyayı source et (ayrı bir alt kabukta çalıştır)
      source "$item"

      # Menü bilgilerini kontrol et
      if [[ -n "$menu_name" && -n "$menu_description" ]]; then
        MENU_ITEMS_SOURCE["$menu_name"]="$menu_description"
        echo "✅ Yüklendi: $item (Menu: $menu_name)"
      
      fi

    elif [ -d "$item" ]; then
      autoload "$item" # Özyineleme
    fi
  done

}
