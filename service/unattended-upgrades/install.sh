#!/usr/bin/env bash
# =============================================================================
# File       : service/unattended-upgrades/install.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Installation unattended-upgrades"
info "Installation d'unattended-upgrades"
run_silent_apt install -y unattended-upgrades apt-listchanges
success "unattended-upgrades installé"
