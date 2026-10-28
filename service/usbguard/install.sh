#!/usr/bin/env bash
# =============================================================================
# File       : service/usbguard/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation USBGuard"
g_log_info "Installation de USBGuard"
g_run_silent_apt install -y usbguard usbguard-notifier
g_run_optional systemctl disable --now usbguard
g_log_success "USBGuard installé, service arrêté jusqu'à la politique"
