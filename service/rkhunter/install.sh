#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/install.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Installation rkhunter"
info "Installation de rkhunter"
run_silent_apt install -y rkhunter
success "rkhunter installé"
