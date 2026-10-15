#!/usr/bin/env bash
# =============================================================================
# File       : service/unattended-upgrades/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation unattended-upgrades"
hf_log_info "Installation d'unattended-upgrades"
hf_run_silent_apt install -y unattended-upgrades apt-listchanges
hf_log_success "unattended-upgrades installé"
