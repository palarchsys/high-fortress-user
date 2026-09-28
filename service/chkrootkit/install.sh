#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/chkrootkit/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/chkrootkit/install.sh
# =============================================================================

# chkrootkit cherche des signes connus de compromission (binaires remplacés,
# interfaces réseau cachées). Le passage a lieu à chaque démarrage.
# Les faux positifs d'une installation fraîche sont listés dans
# service/cron/watchdogs/chkrootkit.ignore.
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
