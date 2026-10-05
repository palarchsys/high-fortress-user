#!/usr/bin/env bash
# =============================================================================
# File       : service/clamav/install.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Installation ClamAV"
info "Installation de ClamAV"
run_silent_apt install -y clamav clamav-daemon clamav-freshclam
success "ClamAV installé"
