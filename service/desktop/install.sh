#!/usr/bin/env bash
# =============================================================================
# File       : service/desktop/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Logiciels du poste"
hf_log_info "Brave, Discord, Thunderbird, KeePassXC et Vencord ne sont pas installés par ce programme."
hf_log_success "Aucun de ces logiciels n'est installé par ce programme."
