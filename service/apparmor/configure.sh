#!/usr/bin/env bash
# =============================================================================
# File       : service/apparmor/configure.sh
# Updated at : 2026-10-20
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Activation AppArmor"
hf_log_info "Activation d'AppArmor"
hf_run_silent systemctl enable --now apparmor
hf_log_success "AppArmor activé"
hf_log_info "Détection des profils userns"
bash "${HF_INSTALL_DIRECTORY}/service/apparmor/detect-and-apply.sh" "${HF_INSTALL_DIRECTORY}"
hf_log_success "Détection des profils terminée"
