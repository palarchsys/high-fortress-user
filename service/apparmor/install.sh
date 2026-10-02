#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/apparmor/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   Installe AppArmor et ses outils. Les profils expérimentaux ne sont pas
#   ajoutés : ils entrent en conflit avec ceux d'Ubuntu.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation AppArmor"
# Pas de apparmor-profiles / apparmor-profiles-extra : profils expérimentaux
# qui entrent en conflit avec ceux d'Ubuntu (Steam, Brave, Thunderbird).
run_silent_apt install -y apparmor apparmor-utils
success "AppArmor installé (profils de la distribution uniquement)"
