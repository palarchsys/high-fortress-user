#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/postfix/install.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   service/postfix/install.sh
# =============================================================================

# Postfix est un relais sortant : il n'accepte pas le courrier du réseau.
# mailutils fournit la commande mail utilisée par les alertes.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Installation de Postfix"
info "Mode « Internet Site » : envoi uniquement, nom de la machine = $(hostname -f)."
run_silent debconf-set-selections << EOF
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string $(hostname -f)
postfix postfix/destinations string $(hostname -f), localhost.localdomain, localhost
EOF
run_silent_apt install --no-install-recommends -y postfix mailutils
run_silent systemctl enable postfix
success "Postfix installé"
