#!/usr/bin/env bash


group="Helpers"
module_name="RegisterModules"
module_description="Registers modules with their names, labels, and groups."
version=1.0.0

RegisterModules() {
  local name="$1" label="$2" group="$3"
  [[ -z "$name" || -z "$label" || -z "$group" ]] && {
    echo "RegisterModules: eksik parametre (name/label/group)"; return 1; }

  MODULE_LABEL["$name"]="$label"
  MODULE_GROUP["$name"]="$group"

  # Aynı modülü aynı gruba iki kez ekleme
  if [[ " ${GROUP_INDEX["$group"]:-} " != *" $name "* ]]; then
    GROUP_INDEX["$group"]="${GROUP_INDEX["$group"]:-} $name"
    GROUP_INDEX["$group"]="${GROUP_INDEX["$group"]# }"
  fi
}
