#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY
source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation AIDE"
g_log_info "Installation d'AIDE"
g_run_silent_apt install -y aide aide-common
g_log_success "AIDE installé"
