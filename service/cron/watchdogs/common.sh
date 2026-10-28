#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/common.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
W_BASE="${W_BASE:-/opt/liltress-workstation}"
LOG_DIR="${W_BASE}/cron/security_logs"
ALERT_DIR="${W_BASE}/cron/alerts"
mkdir -p "${LOG_DIR}" "${ALERT_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${W_BASE}/cron/mail.conf" ]]; then
    # shellcheck disable=SC1091
    source "${W_BASE}/cron/mail.conf"
fi

w_log_pass()  { printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "${LOG_FILE}"; }

g_load_shared_watchdog() {
    local here="$1"
    local candidate
    for candidate in \
        "${here}/watchdog.sh" \
        "${here}/../../../core/watchdog.sh" \
        "${here}/../../../../core/watchdog.sh" \
        "${W_BASE:-}/cron/bin/watchdog.sh" \
        "${G_CONFIG_BASE_DIRECTORY:-}/cron/bin/watchdog.sh"
    do
        if [[ -n "${candidate}" && -f "${candidate}" ]]; then
            # shellcheck disable=SC1090
            source "${candidate}"
            return 0
        fi
    done
    printf '%s\n' "watchdog.sh introuvable" >&2
    return 1
}

g_load_shared_watchdog "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

