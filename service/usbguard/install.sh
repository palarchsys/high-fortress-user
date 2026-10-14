#!/usr/bin/env bash
# =============================================================================
# File       : service/usbguard/install.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Installation USBGuard"
info "Installation de USBGuard"
run_silent_apt install -y usbguard usbguard-notifier
try_silent systemctl disable --now usbguard
success "USBGuard installé, service arrêté jusqu'à la politique"
