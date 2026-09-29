#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/debsums.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   Vérifie les sommes des paquets Ubuntu. Un fichier modifié déclenche une alerte.
# =============================================================================

# debsums -s n'écrit que les fichiers dont l'empreinte a changé.
# Les exclusions ajoutées depuis un e-mail vivent hors de cron/bin :
# une réinstallation recopie les scripts sans effacer cette liste.
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/debsums-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/debsums-${STAMP}.txt"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IGNORE="${HERE}/debsums.ignore"
LOCAL_IGNORE="${HFU_BASE}/cron/debsums.local.ignore"
if ! command -v debsums >/dev/null; then
    log_ok "debsums absent — skip"
    exit 0
fi
set +e
debsums -s > "${LOG_FILE}" 2>&1
set -e
if [[ -f "${IGNORE}" || -f "${LOCAL_IGNORE}" ]]; then
    python3 - "${LOG_FILE}" "${IGNORE}" "${LOCAL_IGNORE}" << 'PY'
import re
import sys
from pathlib import Path

log_path = sys.argv[1]
patterns = []
for ignore_path in sys.argv[2:]:
    path = Path(ignore_path)
    if not path.is_file():
        continue
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            patterns.append(re.compile(line))
        except re.error:
            continue

def ignored(line):
    return any(p.search(line) for p in patterns)

kept = [
    line
    for line in Path(log_path).read_text(errors="replace").splitlines()
    if line.strip() and not ignored(line)
]
Path(log_path).write_text(("\n".join(kept) + "\n") if kept else "")
PY
fi
if [[ -s "${LOG_FILE}" ]]; then
    HFU_DEBSUMS_IGNORE=1 \
        log_alert "debsums : fichiers modifiés (voir ${LOG_FILE})"
else
    log_ok "debsums OK"
fi
exit 0
