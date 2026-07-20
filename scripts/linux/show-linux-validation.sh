#!/usr/bin/env bash

set -u
clear

all_passed=true

show_result() {
    local label="$1"
    local passed="$2"
    local detail="$3"

    if [[ "$passed" == "true" ]]; then
        printf '\033[32m[PASS]\033[0m %s - \033[90m%s\033[0m\n' "$label" "$detail"
    else
        printf '\033[31m[FAIL]\033[0m %s - \033[90m%s\033[0m\n' "$label" "$detail"
        all_passed=false
    fi
}

realm_name="corp.abel-lab.test"
ad_user="apacino@corp.abel-lab.test"
linux_admin_group="gg-linux-admins@corp.abel-lab.test"

printf '\033[36mABELLAB LINUX AND AD INTEGRATION VALIDATION\033[0m\n'
printf 'Validated: %s\n' "$(date --iso-8601=seconds)"
printf 'User:      %s\n' "$(id -un)"
printf 'Server:    %s\n' "$(hostname)"
printf 'Realm:     %s\n\n' "$realm_name"

printf '\033[36mACTIVE DIRECTORY INTEGRATION\033[0m\n'

if sudo -n adcli testjoin --domain="$realm_name" >/dev/null 2>&1; then
    show_result "Machine trust" true "AD domain join is valid"
else
    show_result "Machine trust" false "AD domain join validation failed"
fi

if sudo -n sssctl domain-status "$realm_name" 2>/dev/null | grep -q "Online status: Online"; then
    show_result "SSSD domain" true "Online"
else
    show_result "SSSD domain" false "Offline or unavailable"
fi

if id "$ad_user" >/dev/null 2>&1; then
    show_result "AD identity lookup" true "$ad_user resolved"
else
    show_result "AD identity lookup" false "$ad_user did not resolve"
fi

if getent group "$linux_admin_group" | grep -qi "apacino"; then
    show_result "Linux admin group" true "AD membership resolved"
else
    show_result "Linux admin group" false "AD membership missing"
fi

if sudo -n true >/dev/null 2>&1; then
    show_result "Sudo authorization" true "Delegated through AD group"
else
    show_result "Sudo authorization" false "Noninteractive sudo denied"
fi

printf '\n\033[36mCONTAINERIZED MONITORING SERVICES\033[0m\n'

if systemctl is-active --quiet docker; then
    show_result "Docker service" true "Active"
else
    show_result "Docker service" false "Inactive"
fi

if curl -fsS http://192.168.2.56:9090/-/healthy >/dev/null 2>&1; then
    show_result "Prometheus" true "Health endpoint returned successfully"
else
    show_result "Prometheus" false "Health endpoint unavailable"
fi

if curl -fsS -o /dev/null http://192.168.2.56:3000/login; then
    show_result "Grafana" true "Login endpoint returned successfully"
else
    show_result "Grafana" false "Login endpoint unavailable"
fi

printf '\nOVERALL RESULT: '
if [[ "$all_passed" == "true" ]]; then
    printf '\033[32mPASS\033[0m\n'
    printf 'Cross-platform identity and monitoring services operate as designed.\n'
else
    printf '\033[31mFAIL\033[0m\n'
    printf 'One or more validation checks require attention.\n'
fi
