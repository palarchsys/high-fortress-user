#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/configure.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_current_user

title "Configuration rkhunter"
info "Configuration de rkhunter"
tee /etc/rkhunter.conf.local > /dev/null << EOF
UPDATE_MIRRORS=1
MIRRORS_MODE=0
WEB_CMD=""
UPDATE_LANG="en"
SCRIPTWHITELIST=/usr/bin/lwp-request
ALLOWDEVFILE=/dev/shm/sem.haveged_sem
ALLOWHIDDENFILE=/etc/.resolv.conf.systemd-resolved.bak
ALLOWHIDDENFILE=/etc/.updated
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.steam
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.local/share/Steam
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.config/discord
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.config/BraveSoftware
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.thunderbird
ALLOWHIDDENDIR=/snap
EOF
success "rkhunter.conf.local posé"

if grep -qE '^[[:space:]]*WEB_CMD=' /etc/rkhunter.conf; then
    sed -i 's|^[[:space:]]*WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf
fi

info "Base rkhunter (--propupd) après la purge des paquets."
