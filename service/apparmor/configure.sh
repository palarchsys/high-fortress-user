#!/usr/bin/env bash
# =============================================================================
# File       : service/apparmor/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Activation AppArmor"
g_log_info "Activation d'AppArmor"
g_run_silent systemctl enable --now apparmor
g_log_success "AppArmor activé"
g_log_info "Détection des profils userns"
bash "${G_INSTALL_DIRECTORY}/service/apparmor/detect-and-apply.sh" "${G_INSTALL_DIRECTORY}"
g_log_success "Détection des profils terminée"
