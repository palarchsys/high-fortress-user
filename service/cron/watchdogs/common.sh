#!/usr/bin/env bash
# Fonctions partagées des contrôles planifiés.
# Une alerte est écrite sur disque puis envoyée par Postfix si mail.conf
# contient WATCHDOG_MAIL.
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
log_ok()  { printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "${LOG_FILE}"; }
log_alert() {
    printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "${LOG_FILE}" "${ALERT_FILE}"
    if [[ -n "${WATCHDOG_MAIL:-}" && -x "${HFU_BASE}/cron/bin/send.sh" ]]; then
        TITLE="Alerte" MODULE_NAME="${MODULE_NAME:-contrôle}" CONTENT="$*" \
            WATCHDOG_MAIL="${WATCHDOG_MAIL}" PROJECT_NAME="${PROJECT_NAME:-High-Fortress User}" \
            bash "${HFU_BASE}/cron/bin/send.sh" || true
    fi
}
