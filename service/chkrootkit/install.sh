#!/usr/bin/env bash
# =============================================================================
# File       : service/chkrootkit/install.sh
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

hf_log_title "Installation chkrootkit"
hf_log_info "Installation de chkrootkit"
hf_run_silent_apt install -y chkrootkit
install -d -m 755 "${HF_CONFIG_BASE_DIRECTORY}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/ignore-log.sh" "${HF_CONFIG_BASE_DIRECTORY}/bin/chkrootkit-ignore-log.sh"
hf_log_success "chkrootkit installé"
