#!/usr/bin/env bash
# =============================================================================
# File       : service/auditd/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root
g_get_current_user

g_log_title "Configuration auditd"
g_log_info "Configuration d'auditd"

install -d -m 750 /etc/audit/rules.d
rm -f /etc/audit/rules.d/"${W_PROJECT_SLUG}".rules

w_write_audit_watch() {
    local path="$1" key="$2" field="dir"
    [[ -d "${path}" ]] || field="path"
    printf '%s\n' "-a always,exit -F arch=b64 -F ${field}=${path} -F perm=wa -F key=${key}"
}
grep -v '^#' "$(g_locate_config_file auditd/prelude.rules)" > /etc/audit/rules.d/00-liltress-workstation.rules

w_write_audit_list() {
    local profile path key
    while read -r profile path key; do
        [[ -n "${profile}" && "${profile}" != \#* ]] || continue
        case "${profile}" in
            any) ;;
            virt) g_check_virtual_machine || continue ;;
            *) continue ;;
        esac
        path="${path//__HF_BASE__/${G_CONFIG_BASE_DIRECTORY}}"
        w_write_audit_watch "${path}" "${key}"
    done < "$(g_locate_config_file auditd/watches.list)"
}
{
    w_write_audit_list
    for account_path in \
        "${CURRENT_HOME}/.ssh/authorized_keys" \
        "${CURRENT_HOME}/.bashrc" \
        "${CURRENT_HOME}/.profile" \
        "${CURRENT_HOME}/.bash_profile" \
        "${CURRENT_HOME}/.config/autostart" \
        "${CURRENT_HOME}/.config/systemd/user"
    do
        [[ -e "${account_path}" ]] || continue
        w_write_audit_watch "${account_path}" account
    done
    grep -v '^#' "$(g_locate_config_file auditd/tail.rules)"
} > /etc/audit/rules.d/50-liltress-workstation.rules
grep -v '^#' "$(g_locate_config_file auditd/enable.rules)" > /etc/audit/rules.d/99-liltress-workstation.rules
chmod 640 /etc/audit/rules.d/00-liltress-workstation.rules \
    /etc/audit/rules.d/50-liltress-workstation.rules \
    /etc/audit/rules.d/99-liltress-workstation.rules

g_run_silent systemctl enable auditd
if ! systemctl is-active --quiet auditd; then
    g_run_silent systemctl start auditd
fi

g_run_silent augenrules --load
g_log_success "auditd activé"
