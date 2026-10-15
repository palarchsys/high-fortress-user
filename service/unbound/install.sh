#!/usr/bin/env bash
# =============================================================================
# File       : service/unbound/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation Unbound"
hf_log_info "Installation d'Unbound"
hf_run_silent_apt install -y unbound dns-root-data
hf_log_success "Unbound installé"
