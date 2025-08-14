#!/bin/bash
module_name="GrubPass"
module_description="🔐 Set GRUB password"
group="Utility"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"
GrubPass() {
    # Get the password hash
    echo "Please enter the password for GRUB:"
    pass=$(grub-mkpasswd-pbkdf2 | awk '/grub.pbkdf2/ {print $NF}')
    if [ -z "$pass" ]; then
        echo "ERROR: Failed to generate password hash" >&2
        return 1
    fi

    # Add configuration to 40_custom
    cat <<EOF |  tee -a /etc/grub.d/40_custom >/dev/null
set superusers="root"
password_pbkdf2 root $pass
EOF

    # Update GRUB configuration
    if !  update-grub; then
        echo "ERROR: Failed to update GRUB configuration" >&2
        return 1
    fi

    echo "INFO: Grub password set successfully"
}