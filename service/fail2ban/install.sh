#!/usr/bin/env bash
# =============================================================================
# File       : service/fail2ban/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation Fail2Ban"
hf_log_info "Installation de Fail2Ban"
hf_run_silent_apt install -y fail2ban python3-systemd
hf_log_success "Fail2Ban installé"
