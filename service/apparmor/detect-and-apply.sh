#!/usr/bin/env bash
# =============================================================================
# File       : service/apparmor/detect-and-apply.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Remove an hfu profile that is not shipped.
# Note       : The parser unload is written under cron/security_logs.
# -----------------------------------------------------------------------------

G_INSTALL_DIRECTORY="${1:-${G_INSTALL_DIRECTORY:-}}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

w_log_apparmor_detect() {
    local base="${G_CONFIG_BASE_DIRECTORY:-/opt/liltress-workstation}"
    install -d -m 750 "${base}/cron/security_logs"
    printf '%s %s\n' "$(date -Iseconds)" "$*" >> "${base}/cron/security_logs/apparmor-detect.log"
}

w_remove_unshipped_profile() {
    local installed base
    shopt -s nullglob
    for installed in /etc/apparmor.d/w-*; do
        base="$(basename -- "${installed}")"
        if [[ -f "${G_INSTALL_DIRECTORY}/config/apparmor/${base}" ]]; then
            continue
        fi
        g_log_info "Retrait du profil ${base}"
        if command -v apparmor_parser >/dev/null 2>&1; then
            apparmor_parser -R "${installed}" >/dev/null 2>&1 || true
        fi
        rm -f "${installed}"
        g_log_success "Profil ${base} retiré"
        w_log_apparmor_detect "${base} retiré"
    done
    shopt -u nullglob
}

w_remove_unshipped_profile
