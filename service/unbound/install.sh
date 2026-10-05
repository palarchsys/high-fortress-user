#!/usr/bin/env bash
# =============================================================================
# File       : service/unbound/install.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Installation Unbound"
info "Installation d'Unbound"
run_silent_apt install -y unbound dns-root-data
success "Unbound installé"
