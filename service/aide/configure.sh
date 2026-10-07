#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/configure.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Configuration AIDE"
info "Configuration d'AIDE"
ensure_dir /etc/aide 755
ensure_dir /var/lib/aide 700
sed "s|__HF_BASE__|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/aide.conf" > /etc/aide/aide.conf
install -d -m 755 "${CONFIG_BASE_DIR}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/refresh-db.sh" "${CONFIG_BASE_DIR}/bin/aide-refresh-db.sh"
success "aide.conf posé"
info "Base AIDE après la purge des paquets et rkhunter."
