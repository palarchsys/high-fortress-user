#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/aide/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/aide/install.sh
# =============================================================================

# AIDE compare les binaires et /etc à une base d'empreintes.
# Le paquet est installé ici. La base de référence est créée à la fin
# de run.sh, quand tous les fichiers du poste sont déjà en place.
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
