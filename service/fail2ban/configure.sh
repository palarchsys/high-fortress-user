#!/usr/bin/env bash
# =============================================================================
# File       : service/fail2ban/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
hf_get_ssh_port

hf_log_title "Configuration Fail2Ban"
hf_log_info "Configuration de Fail2Ban"
envsubst '$SSH_PORT' < "$(hf_locate_config_file fail2ban/jail.local)" > /etc/fail2ban/jail.local
chmod 644 /etc/fail2ban/jail.local
hf_log_success "jail.local posé (sshd port ${SSH_PORT})"

hf_log_info "Activation de Fail2Ban"
hf_run_silent systemctl enable --now fail2ban
hf_run_optional fail2ban-client reload
hf_log_success "Fail2Ban activé"
