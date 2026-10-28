#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/init-db.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Base de référence AIDE"
g_log_info "Le calcul des empreintes peut prendre plusieurs minutes."
g_log_info "Le détail reste dans le journal, pas dans le terminal."

g_log_info "Enregistrement de la base de référence AIDE"
aide_log="${G_LOG_DIR:-/var/log/liltress-workstation}/aide-init.log"
mkdir -p "$(dirname "${aide_log}")"

rm -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db.new.gz

if ! aide --config="/etc/aide/aide.conf" --init >"${aide_log}" 2>&1; then
    g_log_warn "aide --init a retourné une erreur. Détail : ${aide_log}"
fi
if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
    mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

    ln -sfn /var/lib/aide/aide.db.gz /var/lib/aide/aide.db
elif [[ -f /var/lib/aide/aide.db.new ]]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
else
    g_log_error "Base AIDE non générée (aide.db.new introuvable). Détail : ${aide_log}"
fi
g_log_success "Base de référence AIDE enregistrée"
