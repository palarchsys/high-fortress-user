#!/usr/bin/env bash
# =============================================================================
# File       : service/unattended-upgrades/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Configuration unattended-upgrades (security only)"
g_log_info "Configuration d'unattended-upgrades (security only)"
g_ensure_directory /etc/apt/apt.conf.d 755

grep -v '^#' "$(g_locate_config_file unattended-upgrades/20auto-upgrades)" > /etc/apt/apt.conf.d/20auto-upgrades
grep -v '^#' "$(g_locate_config_file unattended-upgrades/51liltress-workstation)" > /etc/apt/apt.conf.d/51liltress-workstation
chmod 644 /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/51liltress-workstation

g_run_silent systemctl enable --now unattended-upgrades
g_log_success "unattended-upgrades configuré (security only, reboot auto OFF)"
