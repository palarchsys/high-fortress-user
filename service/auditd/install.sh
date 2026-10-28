#!/usr/bin/env bash
# =============================================================================
# File       : service/auditd/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY
source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation auditd"
g_log_info "Installation d'auditd"
g_run_silent_apt install -y auditd audispd-plugins
g_log_success "auditd installé"
