#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/fail2ban/configure.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/fail2ban/configure.sh
# =============================================================================

# Jails dans jail.local (pas fail2ban.local) — piège P.fail2ban.local
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_ssh_port

title "Configuration Fail2Ban"
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
success "jail.local (sshd port ${SSH_PORT})"

run_silent systemctl enable --now fail2ban
try_silent fail2ban-client reload
success "Fail2Ban actif"
