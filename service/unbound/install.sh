#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/unbound/install.sh
# Créé le    : 2026-09-29
# Créateur   : palarchsys
#
# Rôle
#   service/unbound/install.sh
# =============================================================================

# Unbound résout les noms sur le poste, sans le DNS du FAI.
# dns-root-data fournit la liste des serveurs racine et l'ancre DNSSEC,
# tenues à jour par les paquets Ubuntu.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation Unbound"
run_silent_apt install -y unbound dns-root-data
success "Unbound installé"
