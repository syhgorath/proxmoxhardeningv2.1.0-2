#!/bin/bash

WarnIfLowerThen() { # varname, value, recommended, message
    local name="$1" val="$2" rec="$3" msg="$4"
    [[ "$val" == "unknown" ]] && return 0
    if (( val < rec )); then
      echo -e "${YELLOW}⚠️  $msg (current=$val, recommended>=$rec)${NC}"
    fi
  }