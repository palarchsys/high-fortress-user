#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/init-db.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Base de référence AIDE"
hf_log_info "Le calcul des empreintes peut prendre plusieurs minutes."
hf_log_info "Le détail reste dans le journal, pas dans le terminal."

hf_log_info "Enregistrement de la base de référence AIDE"
aide_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/aide-init.log"
mkdir -p "$(dirname "${aide_log}")"

rm -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db.new.gz

if ! aide --config="/etc/aide/aide.conf" --init >"${aide_log}" 2>&1; then
    hf_log_warn "aide --init a retourné une erreur. Détail : ${aide_log}"
fi
if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
    mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

    ln -sfn /var/lib/aide/aide.db.gz /var/lib/aide/aide.db
elif [[ -f /var/lib/aide/aide.db.new ]]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
else
    hf_log_error "Base AIDE non générée (aide.db.new introuvable). Détail : ${aide_log}"
fi
hf_log_success "Base de référence AIDE enregistrée"
