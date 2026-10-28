#!/usr/bin/env bash
# =============================================================================
# File       : service/rclone/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation de rclone"
if [[ "${G_RCLONE_ALERTS:-0}" != "1" ]]; then
    g_log_info "Envoi Google Drive coupé : rclone n'est pas installé."
    exit 0
fi
g_log_info "Installation de rclone"
g_run_silent_apt install --no-install-recommends -y rclone
token="${G_CONFIG_BASE_DIRECTORY}/cron/rclone.conf"
mode="$(stat -c %a "${token}" 2>/dev/null || true)"
if [[ ! -f "${token}" || "${mode}" != "600" ]]; then
    g_log_error "Jeton Google Drive absent (${token}) ou mode différent de 600."
fi
g_log_success "rclone installé"
