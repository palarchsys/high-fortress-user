#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation AIDE"
hf_log_info "Installation d'AIDE"
hf_run_silent_apt install -y aide aide-common
hf_log_success "AIDE installé"
