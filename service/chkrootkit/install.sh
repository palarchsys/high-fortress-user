#!/usr/bin/env bash
# =============================================================================
# service/chkrootkit/install.sh
# =============================================================================
# chkrootkit cherche des signes connus de compromission (binaires remplacés,
# interfaces réseau cachées). Le passage est planifié par le cron.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation chkrootkit"
run_silent_apt install -y chkrootkit
success "chkrootkit installé"
