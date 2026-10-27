#!/usr/bin/env bash
# =============================================================================
# File       : service/rclone/install.sh
# Updated at : 2026-10-26
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation de rclone"
if [[ "${HF_RCLONE_ALERTS:-0}" != "1" ]]; then
    hf_log_info "Envoi Google Drive coupé : rclone n'est pas installé."
    exit 0
fi
hf_log_info "Installation de rclone"
hf_run_silent_apt install --no-install-recommends -y rclone
token="${HF_CONFIG_BASE_DIRECTORY}/cron/rclone.conf"
mode="$(stat -c %a "${token}" 2>/dev/null || true)"
if [[ ! -f "${token}" || "${mode}" != "600" ]]; then
    hf_log_error "Jeton Google Drive absent (${token}) ou mode différent de 600."
fi
hf_log_success "rclone installé"
