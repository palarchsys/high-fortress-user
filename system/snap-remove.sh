#!/usr/bin/env bash
# =============================================================================
# File       : system/snap-remove.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Conservation de snapd"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

rm -f /etc/apt/preferences.d/no-snap.pref
apt-mark unhold snapd >/dev/null 2>&1 || true
apt-mark unhold firefox >/dev/null 2>&1 || true
if ! dpkg-query -W -f '${Status}' snapd 2>/dev/null | grep -q 'install ok'; then
    hf_log_info "Réinstallation de snapd."
    hf_run_silent_apt install -y snapd
fi

hf_log_success "snapd conservé. Firefox et Thunderbird ne sont pas retirés."
