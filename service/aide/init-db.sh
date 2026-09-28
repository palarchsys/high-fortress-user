#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/aide/init-db.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Enregistre la base de référence AIDE.
# =============================================================================

# run.sh appelle ce script après la recette, juste avant l'e-mail
# de fin. Les paquets, la configuration et les programmes du poste
# sont déjà écrits. La base décrit ce disque : un contrôle ultérieur
# ne signale que ce qui change après l'installation.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Base de référence AIDE"
info "Le calcul des empreintes peut prendre plusieurs minutes."
info "Le détail reste dans le journal, pas dans le terminal."

aide_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/aide-init.log"
mkdir -p "$(dirname "${aide_log}")"
# Une exécution précédente peut avoir laissé le fichier de sortie.
# AIDE refuse de l'écraser. La base en service reste en place tant
# que la nouvelle n'est pas complète.
rm -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db.new.gz

if ! aide --config="/etc/aide/aide.conf" --init >"${aide_log}" 2>&1; then
    warn "aide --init a retourné une erreur. Détail : ${aide_log}"
fi
if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
    mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    # database_in désigne aide.db. La sortie compressée est aide.db.gz.
    ln -sfn /var/lib/aide/aide.db.gz /var/lib/aide/aide.db
elif [[ -f /var/lib/aide/aide.db.new ]]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
else
    error "Base AIDE non générée (aide.db.new introuvable). Détail : ${aide_log}"
fi
success "Base de référence AIDE enregistrée"
