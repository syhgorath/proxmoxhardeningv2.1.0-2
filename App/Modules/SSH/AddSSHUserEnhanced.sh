#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO" >&2' ERR
group="MainMenu"
module_name="AddSSHUserEnhanced"
module_description="🛡️ add ssh user enhanced"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"
AddSSHUserEnhanced() {

    if ! ConfirmAction "Create a new SSH system user?" "n"; then
        return 0
    fi
    whiptail --title "SSH User Management" --msgbox "This wizard will help you create a new SSH user with secure defaults." 10 60 || return 1

    # Get user details
    while true; do
        ssh_user=$(whiptail --inputbox "Enter new SSH username (only lowercase, numbers, - _ allowed):" 10 60 3>&1 1>&2 2>&3)
        [[ $? -ne 0 ]] && return 1
        if [[ -n "$ssh_user" && "$ssh_user" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            if ! id "$ssh_user" &>/dev/null; then
                break
            else
                Log "WARN" "User $ssh_user already exists!"
            fi
        else
            Log "ERROR" "Invalid username. Use lowercase letters, numbers, underscore, or dash."
        fi
    done

    # Get password
    while true; do
        ssh_pass=$(whiptail --passwordbox "Enter password for $ssh_user (min 12 chars):" 10 60 3>&1 1>&2 2>&3)
        ssh_pass_confirm=$(whiptail --passwordbox "Confirm password:" 10 60 3>&1 1>&2 2>&3)
        [[ $? -ne 0 ]] && return 1
        if [[ "$ssh_pass" == "$ssh_pass_confirm" && ${#ssh_pass} -ge 12 ]]; then
            break
        else
            Log "ERROR" "Passwords don't match or too short (minimum 12 characters)"
        fi
    done

    # Create user
    useradd -m -s /bin/bash -c "SSH User - $ssh_user" "$ssh_user"
    echo "$ssh_user:$ssh_pass" | chpasswd

    # Setup SSH directory
    local ssh_dir="/home/$ssh_user/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # Generate SSH key pair
    local key_name="id_ed25519_${ssh_user}"
    ssh-keygen -t ed25519 -N "" -f "$ssh_dir/$key_name" -C "$ssh_user@$(hostname)"
    cat "$ssh_dir/${key_name}.pub" >>"$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "$ssh_user:$ssh_user" "$ssh_dir"

    # Add to SSH allowed users
    if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
        if ! grep -qE "^AllowUsers.*\\b${ssh_user}\\b" /etc/ssh/sshd_config; then
            sed -i "/^AllowUsers/s/$/ ${ssh_user}/" /etc/ssh/sshd_config
        fi
    else
        echo "AllowUsers root $ssh_user" >>/etc/ssh/sshd_config
    fi

    # Optional sudo access
    if whiptail --yesno "Grant sudo privileges to $ssh_user?" 8 50; then
        if ! command -v sudo &>/dev/null; then
            apt install sudo -y
        fi
        usermod -aG sudo "$ssh_user"
        Log "INFO" "Sudo privileges granted to $ssh_user"
    fi

    # Test SSH configuration
    if sshd -t; then
        systemctl reload ssh
        Log "INFO" "SSH configuration updated successfully"
    else
        Log "ERROR" "SSH configuration test failed"
        return 1
    fi

    # Display connection information
    # Bağlantı bilgisi

    whiptail --title "User Created" --msgbox "✅  $ssh_user created successfully!

➡ Host: $IPV4
➡ SSH Private Key: $ssh_dir/$key_name

To download:
scp $ssh_user@$IPV4:$ssh_dir/$key_name ~/.ssh/

Example SSH config:
Host proxmox-$ssh_user
    HostName $IPV4
    User $ssh_user
    IdentityFile ~/.ssh/$key_name
" 20 70
    Log "INFO" "SSH user $ssh_user created and configured"
}
