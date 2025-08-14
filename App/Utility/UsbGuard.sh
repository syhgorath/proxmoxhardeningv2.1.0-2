#!/bin/bash
# Useb Guard.sh

set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="UsbGuard"
module_description="🔒 Enable USBGuard for device control"
version=1.0.0
group="hardening"
RegisterModules "$module_name" "$module_description" "$group"
 UsbGuard() {
  

apt install  usbguard -y

  usbguard generate-policy > /tmp/rules.conf
  install -m 0600 -o root -g root /tmp/rules.conf /etc/usbguard/rules.conf

  systemctl enable usbguard.service
  systemctl start usbguard.service

  if [[ $VERBOSE == "Y" ]]; then
    systemctl status usbguard.service --no-pager
    echo
  fi


}