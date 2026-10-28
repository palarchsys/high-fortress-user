#!/usr/bin/env bash
# =============================================================================
# File       : service/debsums/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation debsums"
g_log_info "Installation de debsums"
g_run_silent_apt install -y debsums
install -d -m 755 "${G_CONFIG_BASE_DIRECTORY}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/ignore-log.sh" "${G_CONFIG_BASE_DIRECTORY}/bin/debsums-ignore-log.sh"

cron_line="$(grep -v '^#' "$(g_locate_config_file debsums/check.conf)" | head -1)"
if [[ -f /etc/default/debsums ]]; then
    if grep -q '^CRON_CHECK=' /etc/default/debsums; then
        sed -i "s/^CRON_CHECK=.*/${cron_line}/" /etc/default/debsums
    else
        printf '%s\n' "${cron_line}" >> /etc/default/debsums
    fi
else
    printf '%s\n' "${cron_line}" > /etc/default/debsums
fi
g_log_success "debsums installé"
