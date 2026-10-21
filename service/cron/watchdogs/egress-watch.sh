#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/egress-watch.sh
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
LOG_FILE="${LOG_DIR}/egress-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/egress-${STAMP}.txt"
MODULE_NAME="Ufw"

if ! command -v journalctl >/dev/null 2>&1; then
    hfu_log_pass "journalctl absent"
    exit 0
fi

stamp="${HFU_BASE}/cron/egress.stamp"

hfu_record_egress_stamp() {
    local moment
    moment="$(date '+%Y-%m-%d %H:%M:%S')"
    install -d -m 750 "${HFU_BASE}/cron"
    printf '%s\n' "${moment}" > "${stamp}"
    chmod 600 "${stamp}"
}

if [[ ! -s "${stamp}" ]] || ! grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "${stamp}"; then
    hfu_record_egress_stamp
    hfu_log_pass "repère initial écrit"
    exit 0
fi

install -d -m 755 /run/high-fortress-user
found="$(mktemp -p /run/high-fortress-user)"
trap 'rm -f "${found}"' EXIT
start="$(head -n 1 "${stamp}")"
journalctl -k --since "${start}" -g 'hfu-egress' --no-pager > "${found}" 2>/dev/null || true
hfu_record_egress_stamp
if ! grep -q 'hfu-egress' "${found}"; then
    hfu_log_pass "aucun flux sortant inattendu"
    exit 0
fi
head -n 40 "${found}" >> "${LOG_FILE}"
hf_log_alert "flux sortants hors des ports 53, 80 et 443"
exit 0
