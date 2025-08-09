#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR

Autoload() {

  local path="$1"

  for item in "$path"/*; do

    # Skip symbolic links (optional)
    [ -L "$item" ] && continue

    if [ -f "$item" ]; then
      # Clear temporary variables
      local menu_name=""
      local menu_description=""
      # Source the file (run in a separate subshell)
      source "$item"

      # Menü bilgilerini kontrol et
      if [[ -n "$menu_name" && -n "$menu_description" ]]; then
        MENU_ITEMS_SOURCE["$menu_name"]="$menu_description"

      fi

    elif [ -d "$item" ]; then
      Autoload "$item" # Özyineleme
    fi
  done

}
