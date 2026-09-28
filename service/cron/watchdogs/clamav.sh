#!/usr/bin/env bash
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/clamav-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/clamav-${STAMP}.txt"
if ! command -v clamscan >/dev/null; then
    log_ok "clamscan absent — skip"
    exit 0
fi
# Scan ciblé : pas Steam / Proton / caches (I/O + faux positifs)
EXCLUDE=(
    --exclude-dir="/.steam"
    --exclude-dir="/Steam"
    --exclude-dir="/.local/share/Steam"
    --exclude-dir="/.cache"
    --exclude-dir="/snap"
    --exclude-dir="/proc"
    --exclude-dir="/sys"
    --exclude-dir="/dev"
    --exclude-dir="/var/lib/libvirt"
    --exclude-dir="/var/lib/docker"
    --exclude-dir="/BraveSoftware"
    --exclude-dir="/.config/discord"
    --exclude-dir="/Telegram"
    --exclude-dir="/.thunderbird"
    --exclude-dir="/thunderbird"
    --exclude-dir="/libvirt"
)
set +e
clamscan -ri /home /opt /tmp "${EXCLUDE[@]}" >> "${LOG_FILE}" 2>&1
rc=$?
set -e
if [[ "${rc}" -ge 2 ]]; then
    log_alert "clamscan erreur rc=${rc}"
elif [[ "${rc}" -eq 1 ]]; then
    log_alert "clamscan : infection(s) (voir ${LOG_FILE})"
else
    log_ok "clamscan OK"
fi
exit 0
