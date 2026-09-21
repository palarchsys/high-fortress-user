#!/usr/bin/env bash
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/rkhunter-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/rkhunter-${STAMP}.txt"
if ! command -v rkhunter >/dev/null; then
    log_ok "rkhunter absent — skip"
    exit 0
fi
rkhunter --update --nocolors >> "${LOG_FILE}" 2>&1 || true
set +e
rkhunter --check --skip-keypress --report-warnings-only --nocolors >> "${LOG_FILE}" 2>&1
rc=$?
set -e
if [[ "${rc}" -ge 2 ]]; then
    log_alert "rkhunter erreur rc=${rc}"
elif [[ "${rc}" -eq 1 ]]; then
    log_alert "rkhunter warnings (voir ${LOG_FILE})"
else
    log_ok "rkhunter OK"
fi
exit 0
