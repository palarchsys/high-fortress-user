#!/usr/bin/env bash
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/debsums-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/debsums-${STAMP}.txt"
if ! command -v debsums >/dev/null; then
    log_ok "debsums absent — skip"
    exit 0
fi
set +e
debsums -s > "${LOG_FILE}" 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 0 || -s "${LOG_FILE}" ]]; then
    log_alert "debsums : fichiers modifiés (voir ${LOG_FILE})"
else
    log_ok "debsums OK"
fi
exit 0
