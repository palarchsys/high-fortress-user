#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/common.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   Fonctions partagées : journal local, puis envoi du courriel d'alerte.
# =============================================================================

# Fonctions partagées des contrôles planifiés.
# Une alerte est écrite sur disque puis envoyée par Postfix si mail.conf
# contient WATCHDOG_MAIL.
set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
LOG_DIR="${HFU_BASE}/cron/security_logs"
ALERT_DIR="${HFU_BASE}/cron/alerts"
mkdir -p "${LOG_DIR}" "${ALERT_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${HFU_BASE}/cron/mail.conf" ]]; then
    # shellcheck disable=SC1091
    source "${HFU_BASE}/cron/mail.conf"
fi
log_ok()  { printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "${LOG_FILE}"; }

# Prépare le texte du courriel : résumé, puis le journal remis en forme.
# Les mots de passe, jetons et clés privées sont remplacés par [masqué].
hfu_alert_excerpt() {
    python3 - "${1:-}" << 'PY'
import re
import sys
from pathlib import Path

path = sys.argv[1]
raw = ""
if path and Path(path).is_file():
    raw = Path(path).read_text(errors="replace")

def redact(text):
    text = re.sub(
        r"(?is)-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----",
        "[clé privée masquée]",
        text,
    )
    text = re.sub(
        r"(?i)\b(password|passwd|token|secret|api[_-]?key|authorization|bearer)\b(\s*[:=]\s*)\S+",
        r"\1\2[masqué]",
        text,
    )
    text = re.sub(r"(?i)\bbearer\s+[A-Za-z0-9._~+/-]{8,}", "Bearer [masqué]", text)
    return text

def clip(lines, limit=120):
    if len(lines) <= limit:
        return lines
    hidden = len(lines) - limit
    return lines[:limit] + [f"... {hidden} ligne(s) supplémentaire(s) non recopiées"]

def format_aide(text):
    kept = []
    interesting = re.compile(
        r"^(summary:|total number|added entries|removed entries|changed entries|"
        r"aide found|start timestamp|end timestamp|f[+-]{3,}:|file:)",
        re.I,
    )
    attr = re.compile(r"^\s{2,}(Size|Perm|Mtime|Ctime|Inode|Linkcount|UID|GID)\s*:", re.I)
    for line in text.splitlines():
        if interesting.search(line.strip()) or interesting.match(line) or attr.match(line):
            kept.append(line.rstrip())
        elif re.match(r"^\s*(added|removed|changed) entries:\s*$", line, re.I):
            kept.append(line.rstrip())
    return clip(kept)

def format_named(name, text):
    low = name.lower()
    lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
    if "aide" in low:
        picked = format_aide(text)
        return picked or clip(lines)
    if "rkhunter" in low:
        picked = [ln for ln in lines if re.search(r"warning|infected|rootkit|suspect", ln, re.I)]
        return clip(picked or lines)
    if "clam" in low:
        picked = [ln for ln in lines if re.search(r"FOUND|virus|infect", ln, re.I)]
        return clip(picked or lines)
    return clip(lines)

name = Path(path).name if path else ""
body = format_named(name, redact(raw))
if body:
    sys.stdout.write("\n".join(body))
PY
}

log_alert() {
    local summary="$*"
    local excerpt="" module
    printf '%s %s\n' "$(date -Iseconds)" "${summary}" | tee -a "${LOG_FILE}" "${ALERT_FILE}"
    excerpt="$(hfu_alert_excerpt "${LOG_FILE:-}")"
    module="${MODULE_NAME:-}"
    if [[ -z "${module}" && -n "${LOG_FILE:-}" ]]; then
        module="$(basename "${LOG_FILE}" | sed -E 's/-[0-9]{8}-.*//')"
    fi
    module="${module:-contrôle}"
    # Second bloc du courriel AIDE seulement, quand l'écart est un
    # changement de fichiers et non une erreur du programme.
    local note="" note_cmd=""
    if [[ "${HFU_AIDE_REFRESH:-}" == "1" ]]; then
        note="Si ce journal correspond à des changements attendus (une mise à jour, un logiciel que vous avez installé, un fichier que vous avez modifié) et qu'il ne révèle pas d'anomalie, exécutez la commande ci-dessous. Elle recalcule la base de référence AIDE à partir du disque actuel."
        note_cmd="sudo bash ${HFU_BASE}/bin/aide-refresh-db.sh"
    fi
    if [[ -n "${WATCHDOG_MAIL:-}" && -x "${HFU_BASE}/cron/bin/send.sh" ]]; then
        TITLE="Alerte ${module}" \
        MODULE_NAME="${module}" \
        CONTENT="${summary}

${excerpt}" \
        NOTE="${note}" \
        NOTE_CMD="${note_cmd}" \
        WATCHDOG_MAIL="${WATCHDOG_MAIL}" \
        PROJECT_NAME="${PROJECT_NAME:-High-Fortress User}" \
            bash "${HFU_BASE}/cron/bin/send.sh" || true
    fi
}
