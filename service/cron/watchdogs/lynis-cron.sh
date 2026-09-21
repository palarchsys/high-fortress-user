#!/usr/bin/env bash
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/lynis-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/lynis-${STAMP}.txt"
if ! command -v lynis >/dev/null; then
    log_ok "lynis absent — skip"
    exit 0
fi
lynis audit system --quick --no-colors --auditor high-fortress-user-cron > "${LOG_FILE}" 2>&1 || true
score="$(grep -E 'hardening_index=' /var/log/lynis-report.dat 2>/dev/null | tail -1 || true)"
log_ok "Lynis ${score}"
chmod 640 /var/log/lynis.log /var/log/lynis-report.dat 2>/dev/null || true
exit 0
