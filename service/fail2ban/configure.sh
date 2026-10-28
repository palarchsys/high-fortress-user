#!/usr/bin/env bash
# =============================================================================
# File       : service/fail2ban/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root
g_get_ssh_port

g_log_title "Configuration Fail2Ban"
g_log_info "Configuration de Fail2Ban"
envsubst '$SSH_PORT' < "$(g_locate_config_file fail2ban/jail.local)" > /etc/fail2ban/jail.local
chmod 644 /etc/fail2ban/jail.local
g_log_success "jail.local posé (sshd port ${SSH_PORT})"

g_log_info "Activation de Fail2Ban"
g_run_silent systemctl enable --now fail2ban
g_run_optional fail2ban-client reload
g_log_success "Fail2Ban activé"
