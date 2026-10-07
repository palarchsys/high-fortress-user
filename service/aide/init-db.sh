#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/init-db.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Base de référence AIDE"
info "Le calcul des empreintes peut prendre plusieurs minutes."
info "Le détail reste dans le journal, pas dans le terminal."

info "Enregistrement de la base de référence AIDE"
aide_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/aide-init.log"
mkdir -p "$(dirname "${aide_log}")"

rm -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db.new.gz

if ! aide --config="/etc/aide/aide.conf" --init >"${aide_log}" 2>&1; then
    warn "aide --init a retourné une erreur. Détail : ${aide_log}"
fi
if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
    mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

    ln -sfn /var/lib/aide/aide.db.gz /var/lib/aide/aide.db
elif [[ -f /var/lib/aide/aide.db.new ]]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
else
    error "Base AIDE non générée (aide.db.new introuvable). Détail : ${aide_log}"
fi
success "Base de référence AIDE enregistrée"
