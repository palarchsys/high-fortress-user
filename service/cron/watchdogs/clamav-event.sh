#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/clamav-event.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Appelé par ClamAV dès qu'une signature reconnaît un fichier surveillé.
#   Écrit le journal et envoie l'e-mail d'alerte.
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
file="${CLAM_VIRUSEVENT_FILENAME:-inconnu}"
virus="${CLAM_VIRUSEVENT_VIRUSNAME:-inconnu}"
LOG_FILE="${LOG_DIR}/clamav-onaccess-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/clamav-onaccess-${STAMP}.txt"
log_alert "ClamAV : ${virus} dans ${file}"
logger -t high-fortress-user -p auth.warning "ClamAV ${virus} ${file}"
