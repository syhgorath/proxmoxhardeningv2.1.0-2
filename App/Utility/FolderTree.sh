#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="FolderTree"
module_description="Display a tree structure of files and directories with sizes."
group="Utility"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"
FolderTree() {
  red='\033[0;31m'
  green='\033[0;32m'
  blue='\033[0;34m'
  cyan='\033[0;36m'
  reset='\033[0m'
  local indent="$1"
  local path="$2"

  for item in "$path"/*; do
    # Sembolik linkleri atla (isteğe bağlı)
    [ -L "$item" ] && continue

    if [ -f "$item" ]; then
      size=$(du -sh "$item" 2>/dev/null | cut -f1)
      printf "${indent}📄 ${red}%-50s${reset} | Boyut: ${cyan}%s${reset}\n" "$(basename "$item")" "$size"
    elif [ -d "$item" ]; then
      printf "${indent}📁 ${blue}%-50s${reset} (Klasör)\n" "$(basename "$item")/"
      autoload "  $indent" "$item" # Özyineleme
    fi
  done
}
