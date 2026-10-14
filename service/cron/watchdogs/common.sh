#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/common.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

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
        picked = []
        keep = False
        for raw in text.splitlines():
            line = raw.rstrip()
            stripped = line.strip()
            if not stripped:
                keep = False
                continue
            if re.search(r"Rootkit Hunter version", line, re.I):
                keep = False
                continue
            if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T", stripped):
                keep = False
                continue
            if re.search(r"warning|infected|rootkit|suspect", line, re.I):
                keep = True
                picked.append(line)
                continue
            if keep and (line[:1] in (" ", "\t") or stripped.startswith("/")):
                picked.append(line)
                continue
            keep = False
        return clip(picked)
    if "clam" in low:
        picked = []
        for raw in text.splitlines():
            line = raw.rstrip()
            stripped = line.strip()
            if not stripped:
                continue
            if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T", stripped):
                continue
            if re.search(
                r"Known viruses:|Infected files:|Engine version:|Scanned directories:|"
                r"Scanned files:|Data scanned:|Data read:|Time:|Start Date:|End Date:",
                line,
            ):
                continue
            if re.search(
                r"Access denied|Can't access|Can't open file|Permission denied|No such file",
                line,
                re.I,
            ):
                continue
            if stripped.endswith(" FOUND") or re.search(
                r"Signature|Fichier|Emplacement|Quarantaine", line
            ):
                picked.append(line)
                continue
            if re.search(r"ERROR:|LibClamAV", line):
                picked.append(line)
        return clip(picked)
    return clip(lines)

name = Path(path).name if path else ""
body = format_named(name, redact(raw))
if body:
    sys.stdout.write("\n".join(body))
PY
}

hfu_clam_kind() {
    python3 - "${1:-}" << 'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] else None
text = path.read_text(errors="replace") if path and path.is_file() else ""
if re.search(r" FOUND$", text, re.M):
    sys.stdout.write("infected")
    raise SystemExit(0)
access = re.compile(
    r"Access denied|Can't access|Can't open file|Permission denied|No such file",
    re.I,
)
summary = re.compile(
    r"Known viruses:|Infected files:|Engine version:|Scanned directories:|"
    r"Scanned files:|Data scanned:|Data read:|^Time:|Start Date:|End Date:"
)
real = False
for raw in text.splitlines():
    line = raw.strip()
    if not line or summary.search(line) or access.search(line):
        continue
    if line.startswith("-----------") or re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T", line):
        continue
    if re.search(r"ERROR:|LibClamAV", line):
        real = True
if real:
    sys.stdout.write("error")
else:
    sys.stdout.write("ok")
PY
}

log_alert() {
    local summary="$*"
    local excerpt="" module
    excerpt="$(hfu_alert_excerpt "${LOG_FILE:-}")"
    printf '%s %s\n' "$(date -Iseconds)" "${summary}" | tee -a "${LOG_FILE}" "${ALERT_FILE}"
    module="${MODULE_NAME:-}"
    if [[ -z "${module}" && -n "${LOG_FILE:-}" ]]; then
        module="$(basename "${LOG_FILE}" | sed -E 's/-[0-9]{8}-.*//')"
    fi
    module="${module:-contrôle}"

    local note="" note_cmd=""
    if [[ "${HFU_AIDE_REFRESH:-}" == "1" ]]; then
        note="Si ce journal correspond à des changements attendus (une mise à jour, un logiciel que vous avez installé, un fichier que vous avez modifié) et qu'il ne révèle pas d'anomalie, exécutez la commande ci-dessous. Elle recalcule la base de référence AIDE à partir du disque actuel."
        note_cmd="sudo bash ${HFU_BASE}/bin/aide-refresh-db.sh"
    elif [[ "${HFU_CHKROOTKIT_IGNORE:-}" == "1" && -n "${LOG_FILE:-}" ]]; then
        note="Si les lignes de ce journal sont des faux positifs que vous reconnaissez, et qu'aucune ne révèle une anomalie, exécutez la commande ci-dessous. Elle enregistre ces détections. Le prochain contrôle de chkrootkit ne les signalera plus."
        note_cmd="sudo bash ${HFU_BASE}/bin/chkrootkit-ignore-log.sh '${LOG_FILE}'"
    elif [[ "${HFU_DEBSUMS_IGNORE:-}" == "1" && -n "${LOG_FILE:-}" ]]; then
        note="Si les lignes de ce journal sont des faux positifs que vous reconnaissez, et qu'aucune ne révèle une anomalie, exécutez la commande ci-dessous. Elle enregistre ces fichiers. Le prochain contrôle de debsums ne les signalera plus."
        note_cmd="sudo bash ${HFU_BASE}/bin/debsums-ignore-log.sh '${LOG_FILE}'"
    elif [[ -n "${HFU_CLAMAV_QUARANTINE:-}" ]]; then
        note="Le fichier a été retiré de son emplacement d'origine. Pour l'afficher sans le remettre en place, copiez la commande ci-dessous."
        note_cmd="$(python3 -c 'import shlex, sys; print("sudo ls -la -- " + shlex.quote(sys.argv[1]))' "${HFU_CLAMAV_QUARANTINE}")"
    fi
    if [[ "${HF_MAIL_ALERTS:-0}" == "1" && -n "${WATCHDOG_MAIL:-}" && -x "${HFU_BASE}/cron/bin/send.sh" ]]; then
        TITLE="Alerte ${module}" \
        MODULE_NAME="${module}" \
        CONTENT="${summary}

${excerpt}" \
        NOTE="${note}" \
        NOTE_CMD="${note_cmd}" \
        WATCHDOG_MAIL="${WATCHDOG_MAIL}" \
        PROJECT_NAME="${PROJECT_NAME:-High-Fortress User}" \
        MAIL_TEMPLATE="${MAIL_TEMPLATE:-mail.html}" \
            bash "${HFU_BASE}/cron/bin/send.sh" || true
    fi
}
