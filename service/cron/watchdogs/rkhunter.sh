#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/rkhunter.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
W_BASE="${W_BASE:-/opt/liltress-workstation}"
# shellcheck disable=SC1091
source "${W_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/rkhunter-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/rkhunter-${STAMP}.txt"
if ! command -v rkhunter >/dev/null; then
    w_log_pass "rkhunter absent — skip"
    exit 0
fi
if [[ -x "${W_BASE}/cron/bin/record-mirrors.sh" ]]; then
    if ! bash "${W_BASE}/cron/bin/record-mirrors.sh" check; then
        g_log_alert "mirrors.dat modifié hors rkhunter --update"
    fi
fi
rk_rc=0
rkhunter --update --nocolors >> "${LOG_FILE}" 2>&1 || rk_rc=$?
if [[ "${rk_rc}" -eq 0 || "${rk_rc}" -eq 2 ]]; then
    bash "${W_BASE}/cron/bin/record-mirrors.sh" save || true
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
G_CONFIRMED_COUNT=0
confirmed_tmp="$(mktemp)"
g_quarantine_confirmed_log rkhunter "${LOG_FILE}" systemd sshd unbound fail2ban gamescope > "${confirmed_tmp}" || true
if [[ -s "${confirmed_tmp}" ]]; then
    cat "${confirmed_tmp}" >> "${LOG_FILE}"
fi
rm -f "${confirmed_tmp}"
if [[ "${rc}" -ge 128 ]]; then
    g_log_alert "$(g_get_crash_sentence "rkhunter" "${rc}")"
elif [[ "${rc}" -ge 2 ]]; then
    g_log_alert "rkhunter erreur rc=${rc}"
elif [[ "${rc}" -eq 1 ]]; then
    if [[ "${G_CONFIRMED_COUNT:-0}" -eq 0 ]]; then
        W_RKHUNTER_REFRESH=1 \
            g_log_alert "rkhunter warnings (voir ${LOG_FILE})"
    else
        g_log_alert "rkhunter warnings (voir ${LOG_FILE})"
    fi
elif [[ "${G_CONFIRMED_COUNT:-0}" -gt 0 ]]; then
    g_log_alert "rkhunter warnings (voir ${LOG_FILE})"
else
    w_log_pass "rkhunter OK"
fi
exit 0
