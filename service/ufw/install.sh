#!/usr/bin/env bash
# =============================================================================
# service/ufw/install.sh
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Installation UFW"
run_silent_apt install -y ufw
run_silent systemctl enable ufw
success "UFW installé"
