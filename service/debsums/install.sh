#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/debsums/install.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/debsums/install.sh
# =============================================================================

# debsums recalcule les empreintes des fichiers des paquets Ubuntu et
# signale ceux qui ne correspondent plus au paquet installé.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation debsums"
run_silent_apt install -y debsums
# Lynis ne voit que cette variable, pas le fichier /etc/cron.d.
# weekly lance le script fourni par le paquet. Le contrôle du mardi
# dans cron.d envoie en plus le résultat par courriel.
if [[ -f /etc/default/debsums ]]; then
    if grep -q '^CRON_CHECK=' /etc/default/debsums; then
        sed -i 's/^CRON_CHECK=.*/CRON_CHECK=weekly/' /etc/default/debsums
    else
        printf '%s\n' 'CRON_CHECK=weekly' >> /etc/default/debsums
    fi
fi
success "debsums installé"
