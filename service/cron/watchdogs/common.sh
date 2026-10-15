#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/common.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
LOG_DIR="${HFU_BASE}/cron/security_logs"
ALERT_DIR="${HFU_BASE}/cron/alerts"
mkdir -p "${LOG_DIR}" "${ALERT_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${HFU_BASE}/cron/mail.conf" ]]; then
    # shellcheck disable=SC1091
    source "${HFU_BASE}/cron/mail.conf"
fi

hfu_log_pass()  { printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "${LOG_FILE}"; }

hf_load_shared_watchdog() {
    local here="$1"
    local candidate
    for candidate in \
        "${here}/watchdog.sh" \
        "${here}/../../../core/watchdog.sh" \
        "${here}/../../../../core/watchdog.sh" \
        "${HFU_BASE:-}/cron/bin/watchdog.sh" \
        "${HF_CONFIG_BASE_DIRECTORY:-}/cron/bin/watchdog.sh"
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

hf_load_shared_watchdog "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

