#!/usr/bin/env bash
# =============================================================================
# service/auditd/configure.sh
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Configuration auditd"
tee /etc/audit/rules.d/"${PROJECT_SLUG}".rules > /dev/null << EOF
# High-Fortress User — règles ciblées (pas de flood Steam/home)
-D
-b 8192
-f 1

-w /etc/ssh -p wa -k ssh-config
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d -p wa -k sudoers
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/apparmor.d -p wa -k apparmor
-w ${CONFIG_BASE_DIR} -p wa -k hfu-config
-w /etc/ufw -p wa -k ufw-config
-w /root -p wa -k root-activity

-a always,exit -F arch=b64 -S adjtimex,settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,stime -k time-change
-w /etc/localtime -p wa -k time-change
EOF

if virt_present; then
    cat >> /etc/audit/rules.d/"${PROJECT_SLUG}".rules << EOF
-w /etc/libvirt -p wa -k libvirt-config
EOF
fi

echo "-e 1" >> /etc/audit/rules.d/"${PROJECT_SLUG}".rules

run_silent systemctl enable --now auditd
try_silent augenrules --load
try_silent systemctl restart auditd
success "auditd actif"
