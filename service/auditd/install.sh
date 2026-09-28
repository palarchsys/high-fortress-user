#!/usr/bin/env bash
# =============================================================================
# service/auditd/install.sh
# =============================================================================
# auditd enregistre qui modifie les fichiers sensibles (comptes, sudo, SSH).
# Les règles précises sont écrites par configure.sh.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation auditd"
run_silent_apt install -y auditd audispd-plugins
success "auditd installé"
