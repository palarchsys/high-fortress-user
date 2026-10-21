#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/behavior.sh
# Updated at : 2026-10-20
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Note       : The stamp lives under the High-Fortress cron directory.
# Note       : The first pass writes the stamp and stays silent.
# -----------------------------------------------------------------------------

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/behavior-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/behavior-${STAMP}.txt"
MODULE_NAME="Auditd"

if ! command -v ausearch >/dev/null 2>&1; then
    hfu_log_pass "ausearch absent"
    exit 0
fi

stamp="${HFU_BASE}/cron/behavior.stamp"

hfu_record_behavior_stamp() {
    local moment
    moment="$(date '+%m/%d/%Y %T')"
    install -d -m 750 "${HFU_BASE}/cron"
    printf '%s\n' "${moment}" > "${stamp}"
    chmod 600 "${stamp}"
}

if [[ ! -s "${stamp}" ]] || ! grep -Eq '^[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "${stamp}"; then
    hfu_record_behavior_stamp
    hfu_log_pass "repère initial écrit"
    exit 0
fi

install -d -m 755 /run/high-fortress-user
found="$(mktemp -p /run/high-fortress-user)"
trap 'rm -f "${found}"' EXIT
start="$(head -n 1 "${stamp}")"
set +e
ausearch -k exec-tmp -ts "${start}" -i > "${found}" 2>>"${LOG_FILE}"
status=$?
set -e
hfu_record_behavior_stamp
if [[ "${status}" -ne 0 ]] || ! grep -q 'exec-tmp' "${found}"; then
    hfu_log_pass "aucune exécution temporaire"
    exit 0
fi
head -n 40 "${found}" >> "${LOG_FILE}"
hf_log_alert "exécution depuis un répertoire temporaire"
exit 0
