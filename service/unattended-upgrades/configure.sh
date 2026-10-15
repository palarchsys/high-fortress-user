#!/usr/bin/env bash
# =============================================================================
# File       : service/unattended-upgrades/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Configuration unattended-upgrades (security only)"
hf_log_info "Configuration d'unattended-upgrades (security only)"
hf_ensure_directory /etc/apt/apt.conf.d 755

grep -v '^#' "$(hf_locate_config_file unattended-upgrades/20auto-upgrades)" > /etc/apt/apt.conf.d/20auto-upgrades
grep -v '^#' "$(hf_locate_config_file unattended-upgrades/51high-fortress-user)" > /etc/apt/apt.conf.d/51high-fortress-user
chmod 644 /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/51high-fortress-user

hf_run_silent systemctl enable --now unattended-upgrades
hf_log_success "unattended-upgrades configuré (security only, reboot auto OFF)"
