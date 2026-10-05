#!/usr/bin/env bash
# =============================================================================
# File       : service/auditd/configure.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Configuration auditd"
info "Configuration d'auditd"

install -d -m 750 /etc/audit/rules.d
rm -f /etc/audit/rules.d/"${PROJECT_SLUG}".rules
hfu_audit_watch() {
    local path="$1" key="$2" field="dir"
    [[ -d "${path}" ]] || field="path"
    printf '%s\n' "-a always,exit -F arch=b64 -F ${field}=${path} -F perm=wa -F key=${key}"
}
cat > /etc/audit/rules.d/00-high-fortress-user.rules << 'EOF'
-D
-b 8192
-f 1
-i
EOF
{
    hfu_audit_watch /etc/ssh ssh-config
    hfu_audit_watch /etc/sudoers sudoers
    hfu_audit_watch /etc/sudoers.d sudoers
    hfu_audit_watch /etc/passwd identity
    hfu_audit_watch /etc/group identity
    hfu_audit_watch /etc/shadow identity
    hfu_audit_watch /etc/gshadow identity
    hfu_audit_watch /etc/apparmor.d apparmor
    hfu_audit_watch "${CONFIG_BASE_DIR}" hfu-config
    hfu_audit_watch /etc/ufw ufw-config
    hfu_audit_watch /root root-activity
    hfu_audit_watch /etc/localtime time-change
    if virt_present; then
        hfu_audit_watch /etc/libvirt libvirt-config
    fi
    printf '%s\n' '-a always,exit -F arch=b64 -S adjtimex -S settimeofday -F key=time-change'
} > /etc/audit/rules.d/50-high-fortress-user.rules
printf '%s\n' '-e 1' > /etc/audit/rules.d/99-high-fortress-user.rules
chmod 640 /etc/audit/rules.d/00-high-fortress-user.rules \
    /etc/audit/rules.d/50-high-fortress-user.rules \
    /etc/audit/rules.d/99-high-fortress-user.rules

run_silent systemctl enable auditd
if ! systemctl is-active --quiet auditd; then
    run_silent systemctl start auditd
fi

run_silent augenrules --load
success "auditd activé"
