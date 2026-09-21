#!/usr/bin/env bash
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/aide-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/aide-${STAMP}.txt"
if ! command -v aide >/dev/null; then
    log_ok "aide absent — skip"
    exit 0
fi
set +e
aide --config=/etc/aide/aide.conf --check > "${LOG_FILE}" 2>&1
rc=$?
set -e
# 0 = ok, 1 = new/removed/changed (alerte), 2+ = erreur
if [[ "${rc}" -eq 0 ]]; then
    log_ok "AIDE: aucun changement"
elif [[ "${rc}" -eq 1 ]]; then
    log_alert "AIDE: changements détectés (voir ${LOG_FILE})"
else
    log_alert "AIDE: erreur rc=${rc}"
fi
find "${LOG_DIR}" -name 'aide-*.log' -mtime +30 -delete 2>/dev/null || true
exit 0
