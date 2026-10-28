#!/usr/bin/env bash
# =============================================================================
# File       : service/clamav/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY
source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation ClamAV"
g_log_info "Installation de ClamAV"
g_run_silent_apt install -y clamav clamav-daemon clamav-freshclam
g_log_success "ClamAV installé"
