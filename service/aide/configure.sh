#!/usr/bin/env bash
# =============================================================================
# service/aide/configure.sh
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Configuration AIDE"
ensure_dir /etc/aide 755
ensure_dir /var/lib/aide 700
sed "s|__HF_BASE__|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/aide.conf" > /etc/aide/aide.conf
success "aide.conf posé"

title "Initialisation base AIDE (peut prendre plusieurs minutes)"
info "aide --init ..."
aide --config="/etc/aide/aide.conf" --init 2>&1 | tail -20 || true
if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
    mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    # AIDE 0.18 : database_in pointe parfois vers aide.db non gzip
    ln -sfn /var/lib/aide/aide.db.gz /var/lib/aide/aide.db 2>/dev/null || true
elif [[ -f /var/lib/aide/aide.db.new ]]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
else
    warn "Base AIDE non générée (aide.db.new introuvable) — relancer plus tard : aide --init"
fi
success "AIDE initialisé"
