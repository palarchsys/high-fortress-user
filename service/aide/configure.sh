#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/aide/configure.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/aide/configure.sh
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Configuration AIDE"
ensure_dir /etc/aide 755
ensure_dir /var/lib/aide 700
sed "s|__HF_BASE__|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/aide.conf" > /etc/aide/aide.conf
install -d -m 755 "${CONFIG_BASE_DIR}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/refresh-db.sh" "${CONFIG_BASE_DIR}/bin/aide-refresh-db.sh"
success "aide.conf posé"
info "La base de référence est calculée à la fin de l'installation, une fois tous les fichiers du poste en place."
