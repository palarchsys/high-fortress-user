#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/hourly-scan.sh
# Updated at : 2026-10-21
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Hourly AIDE, rkhunter, chkrootkit and debsums, in that order.
# Note       : Each script writes its own security log. A clean pass sends no mail.
# -----------------------------------------------------------------------------

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/hourly-scan-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/hourly-scan-${STAMP}.txt"

hfu_run_check() {
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
        hf_log_alert "$(hf_get_crash_sentence "${label}" "${status}")"
    fi
}

hfu_run_check aide.sh "AIDE"
hfu_run_check rkhunter.sh "rkhunter"
hfu_run_check chkrootkit.sh "chkrootkit"
hfu_run_check debsums.sh "debsums"
