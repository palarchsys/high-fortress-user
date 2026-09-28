#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/chkrootkit.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   Lance chkrootkit. Une trouvaille hors liste déclenche une alerte.
# =============================================================================

# chkrootkit -q écrit une ligne par trouvaille. La liste à côté de ce
# script retire les faux positifs d'une installation fraîche. -s retire
# les gestionnaires réseau du test « packet sniffer ».
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/chkrootkit-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/chkrootkit-${STAMP}.txt"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IGNORE="${HERE}/chkrootkit.ignore"
# Exclusions ajoutées depuis un courriel. Hors de cron/bin : une
# réinstallation recopie les scripts sans effacer cette liste.
LOCAL_IGNORE="${HFU_BASE}/cron/chkrootkit.local.ignore"
if ! command -v chkrootkit >/dev/null; then
    log_ok "chkrootkit absent — skip"
    exit 0
fi
set +e
chkrootkit -q -s 'NetworkManager|wpa_supplicant|systemd-networkd' > "${LOG_FILE}" 2>&1
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

kept = [line for line in Path(log_path).read_text(errors="replace").splitlines() if line.strip() and not ignored(line)]
headers = {
    "WARNING: The following suspicious files and directories were found:",
    "WARNING: Possible Linux BPFDoor Malware installed:",
    "WARNING: output from chkwtmp:",
    "WARNING: Output from ifpromisc:",
}
out = []
i = 0
while i < len(kept):
    line = kept[i]
    if line in headers:
        body = []
        j = i + 1
        while j < len(kept) and kept[j] not in headers and not kept[j].startswith("Checking "):
            body.append(kept[j])
            j += 1
        if body:
            out.append(line)
            out.extend(body)
        i = j
        continue
    out.append(line)
    i += 1
Path(log_path).write_text(("\n".join(out) + "\n") if out else "")
PY
fi
if [[ -s "${LOG_FILE}" ]]; then
    HFU_CHKROOTKIT_IGNORE=1 \
        log_alert "chkrootkit a produit une sortie (voir ${LOG_FILE})"
else
    log_ok "chkrootkit silencieux (OK)"
fi
exit 0
