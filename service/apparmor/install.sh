#!/usr/bin/env bash
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation AppArmor"
run_silent_apt install -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra
success "AppArmor installé"
