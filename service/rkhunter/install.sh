#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/rkhunter/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/rkhunter/install.sh
# =============================================================================

# rkhunter cherche des fichiers et des droits habituels d'un rootkit.
# La référence est prise pendant configure.sh, puis revérifiée chaque semaine.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation rkhunter"
run_silent_apt install -y rkhunter
success "rkhunter installé"
