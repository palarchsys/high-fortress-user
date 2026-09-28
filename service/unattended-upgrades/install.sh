#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/unattended-upgrades/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/unattended-upgrades/install.sh
# =============================================================================

# Installe le mécanisme qui applique les mises à jour sans intervention.
# configure.sh le limite aux correctifs de sécurité Ubuntu et Ubuntu Pro.
# apt-listchanges affiche le résumé de ces correctifs dans le journal.
# =============================================================================
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
