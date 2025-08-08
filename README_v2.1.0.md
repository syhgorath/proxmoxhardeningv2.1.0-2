# Proxmox Hardening Script v2.1.0

**Build Date:** 2025-08-08T13:59:21

## Overview of Changes from v2.0.1

* Added `set -euo pipefail`, safe `IFS`, and error trapping to every shell script.
* Included default `trap` for better error logging.
* Inserted uniform directory structure (kept legacy layout for compatibility).
* Added this README and a VERSION file.

## Quick Start
git clone https://github.com/syhgorath/proxmoxhardeningv2.1.0-2.git 
```bash
DRY_RUN=1 ./main.sh   # see actions
sudo ./main.sh        # apply
sudo ./rollback.sh    # rollback
```

Always test in a nested Proxmox environment first.
