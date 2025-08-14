#!/bin/bash
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
module_name="AcctSysstat"
module_description="📊 Setup accounting and system statistics"
version=1.0.0
group="hardening"
RegisterModules "$module_name" "$module_description" "$group"
AcctSysstat(){
 apt-get update
 apt-get install acct sysstat -y 
 systemctl enable --now acct
 sed -i 's/^ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
 systemctl enable --now sysstat

}