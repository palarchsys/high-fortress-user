#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/apparmor/configure.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/apparmor/configure.sh
# =============================================================================

# Active le service AppArmor livré par Ubuntu.
# Les profils déjà installés (navigateur, Thunderbird, Steam) restent
# ceux de la distribution : ce script ne lance pas aa-enforce sur l'ensemble
# des profils et n'installe pas le paquet apparmor-profiles-extra.
#
# service/apparmor/userns.sh pose les profils userns une fois les paquets
# installés, afin de conserver le profil livré par le paquet s'il existe.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Activation AppArmor"
run_silent systemctl enable --now apparmor
success "AppArmor actif"
info "Les profils Ubuntu restent en l'état."
info "La restriction des user namespaces reste celle du système."
