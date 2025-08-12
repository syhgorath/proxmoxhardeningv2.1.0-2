#!/bin/bash
GetSysCtl() { sysctl -n "$1" 2>/dev/null || echo "unknown"; }
