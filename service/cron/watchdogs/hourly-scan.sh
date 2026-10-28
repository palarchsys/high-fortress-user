#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/hourly-scan.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Hourly AIDE, rkhunter, chkrootkit and debsums, in that order.
# Note       : Each script writes its own security log. A clean pass sends no mail.
# -----------------------------------------------------------------------------

set -euo pipefail
W_BASE="${W_BASE:-/opt/liltress-workstation}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${W_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/hourly-scan-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/hourly-scan-${STAMP}.txt"

w_run_check() {
    local script="$1"
    local label="$2"
    local status=0
    if [[ ! -x "${HERE}/${script}" ]]; then
        return 0
    fi
    set +e
    bash "${HERE}/${script}"
    status=$?
    set -e
    if [[ "${status}" -ne 0 ]]; then
        g_log_alert "$(g_get_crash_sentence "${label}" "${status}")"
    fi
}

w_run_check aide.sh "AIDE"
w_run_check rkhunter.sh "rkhunter"
w_run_check chkrootkit.sh "chkrootkit"
w_run_check debsums.sh "debsums"
