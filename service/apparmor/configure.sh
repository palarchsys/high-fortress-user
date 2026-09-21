#!/usr/bin/env bash
# =============================================================================
# service/apparmor/configure.sh
# =============================================================================
# Service enabled. PAS d'aa-enforce global (piège P.apparmor.enforce).
# Les profils distro Firefox / snaps restent tels quels.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Activation AppArmor"
run_silent systemctl enable --now apparmor
success "AppArmor actif"

info "Aucun aa-enforce global — profils Ubuntu / snap / Firefox intacts."
try_silent systemctl reload apparmor
success "AppArmor : distro only"
