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
# service/cron/watchdogs/chkrootkit.ignore. Les lignes acceptées
# ensuite depuis un e-mail vont dans cron/chkrootkit.local.ignore.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation chkrootkit"
run_silent_apt install -y chkrootkit
install -d -m 755 "${CONFIG_BASE_DIR}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/ignore-log.sh" "${CONFIG_BASE_DIR}/bin/chkrootkit-ignore-log.sh"
success "chkrootkit installé"
