#!/usr/bin/env bash



register_module() {
  local name="$1" label="$2" group="$3"
  [[ -z "$name" || -z "$label" || -z "$group" ]] && {
    echo "register_module: eksik parametre (name/label/group)"; return 1; }

  MODULE_LABEL["$name"]="$label"
  MODULE_GROUP["$name"]="$group"

  # Aynı modülü aynı gruba iki kez ekleme
  if [[ " ${GROUP_INDEX["$group"]} " != *" $name "* ]]; then
    GROUP_INDEX[$group]="${GROUP_INDEX[$group]} $name"
    GROUP_INDEX[$group]="${GROUP_INDEX[$group]# }"
  fi
}
