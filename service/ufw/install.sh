#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/ufw/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/ufw/install.sh — pare-feu UFW
# =============================================================================

# Installe le pare-feu et active le service. Les règles (entrées refusées,
# sorties autorisées, réseau des machines virtuelles) sont dans configure.sh.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Installation UFW"
run_silent_apt install -y ufw
run_silent systemctl enable ufw
success "UFW installé"
