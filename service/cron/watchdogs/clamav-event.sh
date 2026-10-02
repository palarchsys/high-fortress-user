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
base="$(basename -- "${file}")"
[[ -n "${base}" && "${base}" != "/" ]] || base="inconnu"
# Même dossier que le serveur. Le drop-in de clamonacc y déplace le fichier.
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
