#!/usr/bin/env bash
# =============================================================================
# File       : system/snapd.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "snapd"
g_log_info "Installation de snapd"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

rm -f /etc/apt/preferences.d/no-snap.pref
apt-mark unhold snapd >/dev/null 2>&1 || true
apt-mark unhold firefox >/dev/null 2>&1 || true
if ! dpkg-query -W -f '${Status}' snapd 2>/dev/null | grep -q 'install ok'; then
    g_run_silent_apt install -y snapd
fi

g_log_success "snapd installé"
