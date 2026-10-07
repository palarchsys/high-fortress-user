#!/usr/bin/env bash
# =============================================================================
# File       : service/fail2ban/configure.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root
detect_ssh_port

title "Configuration Fail2Ban"
info "Configuration de Fail2Ban"
tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
allowipv6 = auto
banaction = ufw
banaction_allports = ufw
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
backend = systemd
maxretry = 5
bantime = 1h
EOF
success "jail.local posé (sshd port ${SSH_PORT})"

info "Activation de Fail2Ban"
run_silent systemctl enable --now fail2ban
try_silent fail2ban-client reload
success "Fail2Ban activé"
