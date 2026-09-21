#!/usr/bin/env bash
# Sourcé par les watchdogs.
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
LOG_DIR="${HFU_BASE}/cron/security_logs"
ALERT_DIR="${HFU_BASE}/cron/alerts"
mkdir -p "${LOG_DIR}" "${ALERT_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
log_ok()  { printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "${LOG_FILE}"; }
log_alert() {
    printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "${LOG_FILE}" "${ALERT_FILE}"
}
