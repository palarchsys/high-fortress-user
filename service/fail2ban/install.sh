#!/usr/bin/env bash
# =============================================================================
# File       : service/fail2ban/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY
source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation Fail2Ban"
g_log_info "Installation de Fail2Ban"
g_run_silent_apt install -y fail2ban python3-systemd
g_log_success "Fail2Ban installé"
