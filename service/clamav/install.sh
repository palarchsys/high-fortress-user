#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/clamav/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/clamav/install.sh
# =============================================================================

# Moteur antivirus et téléchargement des signatures. La surveillance
# continue est limitée aux Téléchargements et au Bureau. Le passage
# du lundi couvre le reste, dont /tmp.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation ClamAV"
run_silent_apt install -y clamav clamav-daemon clamav-freshclam
success "ClamAV installé"
