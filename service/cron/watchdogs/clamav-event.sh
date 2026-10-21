#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/clamav-event.sh
# Updated at : 2026-10-20
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
file="${CLAM_VIRUSEVENT_FILENAME:-inconnu}"
virus="${CLAM_VIRUSEVENT_VIRUSNAME:-inconnu}"
base="$(basename -- "${file}")"
[[ -n "${base}" && "${base}" != "/" ]] || base="inconnu"
case "${base}" in
    .clamav-quarantine-lock.*) exit 0 ;;
esac

LOG_FILE="${LOG_DIR}/clamav-onaccess-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/clamav-onaccess-${STAMP}.txt"
MODULE_NAME="Clamav"
export LOG_FILE ALERT_FILE MODULE_NAME HFU_BASE
export HFU_CLAMAV_EVENT_FILE="${file}"
export HFU_CLAMAV_EVENT_VIRUS="${virus}"
export HFU_CLAMAV_EVENT_KIND=onaccess
export HFU_CLAMAV_EVENT_MAIL=1
export HFU_CLAMAV_RESPONSE_STAMP="${STAMP}"
response="${HFU_BASE}/cron/bin/clamav-response.sh"
if [[ ! -x "${response}" ]]; then
    response="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/clamav-response.sh"
fi
bash "${response}" || true
if [[ -f "${LOG_DIR}/clamav-response-${STAMP}.path" ]]; then
    HFU_CLAMAV_QUARANTINE="$(cat "${LOG_DIR}/clamav-response-${STAMP}.path")"
    export HFU_CLAMAV_QUARANTINE
fi
hf_arm_crash_mail "ClamAV accès"
logger -t high-fortress-user -p auth.warning "ClamAV ${virus} origine=${file} quarantaine=${HFU_CLAMAV_QUARANTINE:-inconnue}"
hf_log_alert "ClamAV : ${virus} dans ${file}"
