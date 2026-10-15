#!/usr/bin/env bash
# =============================================================================
# File       : service/apparmor/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation AppArmor"

hf_log_info "Installation d'AppArmor"
hf_run_silent_apt install -y apparmor apparmor-utils
hf_log_success "AppArmor installé (profils de la distribution uniquement)"
