#!/usr/bin/env bash
# =============================================================================
# service/clamav/configure.sh
# =============================================================================
# Daemon + freshclam. PAS de clamonacc (I/O Steam / home).
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Configuration ClamAV"
info "Pas d'OnAccess (Steam / Discord / home) — scan hebdomadaire via cron."

try_silent systemctl stop clamav-freshclam clamav-daemon clamonacc.service
try_silent systemctl disable --now clamonacc.service
try_silent systemctl mask clamonacc.service

info "Mise à jour des signatures (peut prendre 1–2 min)..."
freshclam --quiet 2>/dev/null || warn "freshclam initial : signatures via le service au prochain démarrage"

run_silent systemctl enable --now clamav-freshclam
run_silent systemctl enable --now clamav-daemon
success "clamav-daemon + freshclam actifs (OnAccess masqué)"
