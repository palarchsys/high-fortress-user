#!/usr/bin/env bash
# =============================================================================
# File       : service/auditd/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
hf_get_current_user

hf_log_title "Configuration auditd"
hf_log_info "Configuration d'auditd"

install -d -m 750 /etc/audit/rules.d
rm -f /etc/audit/rules.d/"${HFU_PROJECT_SLUG}".rules

hfu_write_audit_watch() {
    local path="$1" key="$2" field="dir"
    [[ -d "${path}" ]] || field="path"
    printf '%s\n' "-a always,exit -F arch=b64 -F ${field}=${path} -F perm=wa -F key=${key}"
}
grep -v '^#' "$(hf_locate_config_file auditd/prelude.rules)" > /etc/audit/rules.d/00-high-fortress-user.rules

hfu_write_audit_list() {
    local profile path key
    while read -r profile path key; do
        [[ -n "${profile}" && "${profile}" != \#* ]] || continue
        case "${profile}" in
            any) ;;
            virt) hf_check_virtual_machine || continue ;;
            *) continue ;;
        esac
        path="${path//__HF_BASE__/${HF_CONFIG_BASE_DIRECTORY}}"
        hfu_write_audit_watch "${path}" "${key}"
    done < "$(hf_locate_config_file auditd/watches.list)"
}
{
    hfu_write_audit_list
    for account_path in \
        "${CURRENT_HOME}/.ssh/authorized_keys" \
        "${CURRENT_HOME}/.bashrc" \
        "${CURRENT_HOME}/.profile" \
        "${CURRENT_HOME}/.bash_profile" \
        "${CURRENT_HOME}/.config/autostart" \
        "${CURRENT_HOME}/.config/systemd/user"
    do
        [[ -e "${account_path}" ]] || continue
        hfu_write_audit_watch "${account_path}" account
    done
    grep -v '^#' "$(hf_locate_config_file auditd/tail.rules)"
} > /etc/audit/rules.d/50-high-fortress-user.rules
grep -v '^#' "$(hf_locate_config_file auditd/enable.rules)" > /etc/audit/rules.d/99-high-fortress-user.rules
chmod 640 /etc/audit/rules.d/00-high-fortress-user.rules \
    /etc/audit/rules.d/50-high-fortress-user.rules \
    /etc/audit/rules.d/99-high-fortress-user.rules

hf_run_silent systemctl enable auditd
if ! systemctl is-active --quiet auditd; then
    hf_run_silent systemctl start auditd
fi

hf_run_silent augenrules --load
hf_log_success "auditd activé"
