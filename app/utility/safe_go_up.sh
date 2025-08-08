#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
safe_go_up() {
  local target_dir="$PWD"
  for ((i=0; i<$1; i++)); do
    if [[ "$target_dir" == "/" ]]; then
      echo "Hata: Kök dizine ulaşıldı!"
      return 1
    fi
    target_dir=$(dirname "$target_dir")
  done
  echo "$target_dir"
}