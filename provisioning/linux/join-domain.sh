#!/usr/bin/env bash

set -euo pipefail

realm_name="${REALM_NAME:-corp.abel-lab.test}"
join_user="${JOIN_USER:-Administrator}"
linux_admin_group="${LINUX_ADMIN_GROUP:-GG-Linux-Admins}"

if [[ "${1:-}" != "--apply" ]]; then
    cat <<EOF
This script installs the Ubuntu AD client packages and joins ${realm_name}.

Review the variables first, then run:
  sudo REALM_NAME=${realm_name} JOIN_USER=${join_user} \\
    LINUX_ADMIN_GROUP=${linux_admin_group} $0 --apply

The domain password is requested interactively and is never stored.
EOF
    exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
    printf 'Run with sudo so packages and system configuration can be changed.\n' >&2
    exit 1
fi

apt-get update
apt-get install -y \
    realmd \
    sssd \
    sssd-tools \
    libnss-sss \
    libpam-sss \
    adcli \
    samba-common-bin \
    packagekit

realm discover "$realm_name"
realm join "$realm_name" -U "$join_user"
pam-auth-update --enable mkhomedir
sss_cache -E

realm permit -g "${linux_admin_group}@${realm_name}"

sudoers_path="/etc/sudoers.d/abellab-linux-admins"
printf '%%%s@%s ALL=(ALL:ALL) ALL\n' \
    "${linux_admin_group,,}" \
    "$realm_name" > "$sudoers_path"
chmod 0440 "$sudoers_path"
visudo -cf "$sudoers_path"

adcli testjoin --domain="$realm_name"
sssctl domain-status "$realm_name"
realm list

printf 'Domain join and AD-group authorization completed.\n'
