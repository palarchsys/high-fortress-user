#!/usr/bin/env bash
# =============================================================================
# File       : service/debsums/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation debsums"
hf_log_info "Installation de debsums"
hf_run_silent_apt install -y debsums
install -d -m 755 "${HF_CONFIG_BASE_DIRECTORY}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/ignore-log.sh" "${HF_CONFIG_BASE_DIRECTORY}/bin/debsums-ignore-log.sh"

cron_line="$(grep -v '^#' "$(hf_locate_config_file debsums/debsums.default)" | head -1)"
if [[ -f /etc/default/debsums ]]; then
    if grep -q '^CRON_CHECK=' /etc/default/debsums; then
        sed -i "s/^CRON_CHECK=.*/${cron_line}/" /etc/default/debsums
    else
        printf '%s\n' "${cron_line}" >> /etc/default/debsums
    fi
else
    printf '%s\n' "${cron_line}" > /etc/default/debsums
fi
hf_log_success "debsums installé"
