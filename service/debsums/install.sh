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
# Le paquet lance son propre cron si CRON_CHECK vaut daily, weekly
# ou monthly. La passe de démarrage s'en charge. Cette valeur
# laisse les scripts du paquet sans effet.
if [[ -f /etc/default/debsums ]]; then
    if grep -q '^CRON_CHECK=' /etc/default/debsums; then
        sed -i 's/^CRON_CHECK=.*/CRON_CHECK=no/' /etc/default/debsums
    else
        printf '%s\n' 'CRON_CHECK=no' >> /etc/default/debsums
    fi
else
    printf '%s\n' 'CRON_CHECK=no' > /etc/default/debsums
fi
success "debsums installé"
