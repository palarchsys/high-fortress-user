#!/usr/bin/env bash
# =============================================================================
# service/fail2ban/install.sh
# =============================================================================
# Fail2Ban lit le journal d'authentification et demande à UFW de bloquer
# une adresse qui échoue plusieurs fois à SSH. python3-systemd permet
# à Fail2Ban de lire le journal via journald.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation Fail2Ban"
run_silent_apt install -y fail2ban python3-systemd
success "Fail2Ban installé"
