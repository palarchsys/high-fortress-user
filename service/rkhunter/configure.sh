#!/usr/bin/env bash
# =============================================================================
# service/rkhunter/configure.sh
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_current_user

title "Configuration rkhunter"
tee /etc/rkhunter.conf.local > /dev/null << EOF
UPDATE_MIRRORS=1
MIRRORS_MODE=0
WEB_CMD=""
UPDATE_LANG="en"
SCRIPTWHITELIST=/usr/bin/lwp-request
ALLOWDEVFILE=/dev/shm/sem.haveged_sem
ALLOWHIDDENFILE=/etc/.resolv.conf.systemd-resolved.bak
ALLOWHIDDENFILE=/etc/.updated
# Steam / Proton / Discord / snaps : faux positifs fréquents
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.steam
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.local/share/Steam
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.config/discord
ALLOWHIDDENDIR=/home/${CURRENT_USER}/.config/telegramdesktop
ALLOWHIDDENDIR=/snap
EOF
success "rkhunter.conf.local"

if grep -qE '^[[:space:]]*WEB_CMD=' /etc/rkhunter.conf; then
    sed -i 's|^[[:space:]]*WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf
fi

title "Baseline rkhunter"
rk_out=""
rk_rc=0
rk_out=$(rkhunter --update --nocolors 2>&1) || rk_rc=$?
case "${rk_rc}" in
    0|2) ;;
    *) warn "rkhunter --update rc=${rk_rc} (poursuivi) : ${rk_out}" ;;
esac

run_silent rkhunter --propupd
rk_tmp="/var/lib/rkhunter/tmp"
if [[ -d "${rk_tmp}" ]]; then
    cp -f -p /etc/passwd "${rk_tmp}/passwd"
    cp -f -p /etc/group "${rk_tmp}/group"
fi
success "Baseline rkhunter enregistrée"
