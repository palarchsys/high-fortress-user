#!/usr/bin/env bash
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/chkrootkit-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/chkrootkit-${STAMP}.txt"
if ! command -v chkrootkit >/dev/null; then
    log_ok "chkrootkit absent — skip"
    exit 0
fi
set +e
chkrootkit -q > "${LOG_FILE}" 2>&1
rc=$?
set -e
if [[ -s "${LOG_FILE}" ]]; then
    log_alert "chkrootkit a produit une sortie (voir ${LOG_FILE})"
else
    log_ok "chkrootkit silencieux (OK)"
fi
exit 0
