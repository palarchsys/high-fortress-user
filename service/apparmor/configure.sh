#!/usr/bin/env bash
# =============================================================================
# File       : service/apparmor/configure.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Activation AppArmor"
info "Activation d'AppArmor"
run_silent systemctl enable --now apparmor
success "AppArmor activé"
info "Les profils Ubuntu restent en l'état."
info "La restriction des user namespaces reste celle du système."
