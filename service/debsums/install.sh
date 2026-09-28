#!/usr/bin/env bash
# =============================================================================
# service/debsums/install.sh
# =============================================================================
# debsums recalcule les empreintes des fichiers des paquets Ubuntu et
# signale ceux qui ne correspondent plus au paquet installé.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation debsums"
run_silent_apt install -y debsums
success "debsums installé"
