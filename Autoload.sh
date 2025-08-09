#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# RegisterModules fonksiyonu burada hazır olmalı
# source "$(dirname "$0")/App/Helpers/RegisterModules.sh"  <-- üstten çağırdığın yerde zaten sourced ise burada gerekmez.

Autoload() {
  local path="$1"
  shopt -s nullglob
  for item in "$path"/*; do
    [ -L "$item" ] && continue
    if [ -f "$item" ]; then
      source "$item"   # dosya içinde RegisterModules(...) çağrılır
    elif [ -d "$item" ]; then
      Autoload "$item"
    fi
  done
}
