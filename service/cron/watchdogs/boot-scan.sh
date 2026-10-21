#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/boot-scan.sh
# Updated at : 2026-10-20
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/boot-scan-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/boot-scan-${STAMP}.txt"
: > "${LOG_FILE}"

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

hfu_run_check apply-scan-skip.sh "préparation des exclusions"
hfu_run_check aide.sh "AIDE"
hfu_run_check integrity.sh "intégrité"
hfu_run_check rkhunter.sh "rkhunter"
hfu_run_check behavior.sh "audit"
hfu_run_check chkrootkit.sh "chkrootkit"
hfu_run_check clamav.sh "ClamAV"
hfu_run_check debsums.sh "debsums"
hfu_run_check egress-watch.sh "journal sortant"
