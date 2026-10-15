#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
hf_get_current_user
HFU_ACCOUNT_USER="${CURRENT_USER}"
export HFU_ACCOUNT_USER

hf_log_title "Configuration rkhunter"
hf_log_info "Configuration de rkhunter"
envsubst '$HFU_ACCOUNT_USER' < "$(hf_locate_config_file rkhunter/rkhunter.conf.local)" > /etc/rkhunter.conf.local
chmod 644 /etc/rkhunter.conf.local
hf_log_success "rkhunter.conf.local posé"

if grep -qE '^[[:space:]]*WEB_CMD=' /etc/rkhunter.conf; then
    sed -i 's|^[[:space:]]*WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf
fi

hf_log_info "Base rkhunter (--propupd) après la purge des paquets."
