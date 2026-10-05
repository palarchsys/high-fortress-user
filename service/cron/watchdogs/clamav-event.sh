#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/clamav-event.sh
# Updated at : 2026-10-05
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

quarantine="/var/lib/clamav/quarantine/${base}"
LOG_FILE="${LOG_DIR}/clamav-onaccess-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/clamav-onaccess-${STAMP}.txt"
MODULE_NAME="Clamav"
printf '%s\n' \
    "Signature : ${virus}" \
    "Fichier : ${base}" \
    "Emplacement d'origine : ${file}" \
    "Quarantaine : ${quarantine}" > "${LOG_FILE}"
logger -t high-fortress-user -p auth.warning "ClamAV ${virus} origine=${file} quarantaine=${quarantine}"
HFU_CLAMAV_QUARANTINE="${quarantine}" \
    log_alert "ClamAV : ${virus} dans ${file}"
