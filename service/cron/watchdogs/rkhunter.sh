#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/rkhunter.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/rkhunter-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/rkhunter-${STAMP}.txt"
if ! command -v rkhunter >/dev/null; then
    hfu_log_pass "rkhunter absent — skip"
    exit 0
fi
if [[ -x "${HFU_BASE}/cron/bin/record-mirrors.sh" ]]; then
    if ! bash "${HFU_BASE}/cron/bin/record-mirrors.sh" check; then
        hf_log_alert "mirrors.dat modifié hors rkhunter --update"
    fi
fi
rk_rc=0
rkhunter --update --nocolors >> "${LOG_FILE}" 2>&1 || rk_rc=$?
if [[ "${rk_rc}" -eq 0 || "${rk_rc}" -eq 2 ]]; then
    bash "${HFU_BASE}/cron/bin/record-mirrors.sh" save || true
fi
rk_local=/etc/rkhunter.conf.local
touch "${rk_local}"
for allow in '/dev/shm/*' '/dev/shm/*/*' '/dev/shm/*/*/*' '/dev/log'; do
    if ! grep -qxF "ALLOWDEVFILE=${allow}" "${rk_local}"; then
        printf 'ALLOWDEVFILE=%s\n' "${allow}" >> "${rk_local}"
    fi
done
set +e
rkhunter --check --skip-keypress --report-warnings-only --nocolors >> "${LOG_FILE}" 2>&1
rc=$?
set -e
if [[ "${rc}" -ge 128 ]]; then
    hf_log_alert "$(hf_get_crash_sentence "rkhunter" "${rc}")"
elif [[ "${rc}" -ge 2 ]]; then
    hf_log_alert "rkhunter erreur rc=${rc}"
elif [[ "${rc}" -eq 1 ]]; then
    hf_log_alert "rkhunter warnings (voir ${LOG_FILE})"
else
    hfu_log_pass "rkhunter OK"
fi
exit 0
