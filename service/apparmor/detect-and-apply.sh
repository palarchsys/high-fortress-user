#!/usr/bin/env bash
# =============================================================================
# File       : service/apparmor/detect-and-apply.sh
# Updated at : 2026-10-20
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Remove an hfu profile that is not shipped.
# Note       : The parser unload is written under cron/security_logs.
# -----------------------------------------------------------------------------

HF_INSTALL_DIRECTORY="${1:-${HF_INSTALL_DIRECTORY:-}}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hfu_log_apparmor_detect() {
    local base="${HF_CONFIG_BASE_DIRECTORY:-/opt/high-fortress-user}"
    install -d -m 750 "${base}/cron/security_logs"
    printf '%s %s\n' "$(date -Iseconds)" "$*" >> "${base}/cron/security_logs/apparmor-detect.log"
}

hfu_remove_unshipped_profile() {
    local installed base
    shopt -s nullglob
    for installed in /etc/apparmor.d/hfu-*; do
        base="$(basename -- "${installed}")"
        if [[ -f "${HF_INSTALL_DIRECTORY}/config/apparmor/${base}" ]]; then
            continue
        fi
        hf_log_info "Retrait du profil ${base}"
        if command -v apparmor_parser >/dev/null 2>&1; then
            apparmor_parser -R "${installed}" >/dev/null 2>&1 || true
        fi
        rm -f "${installed}"
        hf_log_success "Profil ${base} retiré"
        hfu_log_apparmor_detect "${base} retiré"
    done
    shopt -u nullglob
}

hfu_remove_unshipped_profile
