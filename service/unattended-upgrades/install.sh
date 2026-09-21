#!/usr/bin/env bash
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation unattended-upgrades"
run_silent_apt install -y unattended-upgrades apt-listchanges
success "unattended-upgrades installé"
