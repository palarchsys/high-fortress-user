#!/usr/bin/env bash
# =============================================================================
# File       : service/debsums/install.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Installation debsums"
info "Installation de debsums"
run_silent_apt install -y debsums
install -d -m 755 "${CONFIG_BASE_DIR}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/ignore-log.sh" "${CONFIG_BASE_DIR}/bin/debsums-ignore-log.sh"

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
