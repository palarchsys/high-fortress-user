#!/usr/bin/env bash
# =============================================================================
# service/clamav/install.sh
# =============================================================================
# Moteur antivirus et téléchargement des signatures. Le scan à l'ouverture
# des fichiers (OnAccess) n'est pas activé : il ralentit les jeux et le
# dossier personnel. Un passage hebdomadaire est planifié par le cron.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE
source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
title "Installation ClamAV (pas OnAccess)"
run_silent_apt install -y clamav clamav-daemon clamav-freshclam
success "ClamAV installé"
