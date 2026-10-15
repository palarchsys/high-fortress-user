#!/usr/bin/env bash
# =============================================================================
# File       : service/usbguard/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation USBGuard"
hf_log_info "Installation de USBGuard"
hf_run_silent_apt install -y usbguard usbguard-notifier
hf_run_optional systemctl disable --now usbguard
hf_log_success "USBGuard installé, service arrêté jusqu'à la politique"
