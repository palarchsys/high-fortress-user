#!/usr/bin/env bash
# =============================================================================
# service/aide/install.sh
# =============================================================================
# AIDE construit une base d'empreintes des binaires et de /etc.
# Une modification inattendue de ces fichiers apparaît au contrôle suivant.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation AIDE"
run_silent_apt install -y aide aide-common
success "AIDE installé"
