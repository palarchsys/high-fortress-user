#!/usr/bin/env bash
# =============================================================================
# File       : service/postfix/install.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Installation de Postfix"
info "Installation de Postfix (envoi seul, Internet Site)"
run_silent debconf-set-selections << EOF
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string $(hostname -f)
postfix postfix/destinations string $(hostname -f), localhost.localdomain, localhost
EOF
run_silent_apt install --no-install-recommends -y postfix mailutils
run_silent systemctl enable postfix
success "Postfix installé"
