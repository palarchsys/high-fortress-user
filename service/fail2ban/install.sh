#!/usr/bin/env bash
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation Fail2Ban"
run_silent_apt install -y fail2ban python3-systemd
success "Fail2Ban installé"
