#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/send.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Envoi d'une alerte HTML via la commande mail (Postfix local).
#   Variables : DIR ou chemin du script, MODULE_NAME, CONTENT, TITLE,
#   WATCHDOG_MAIL, PROJECT_NAME.
#   Un corps vide n'est pas envoyé.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"
TITLE="${TITLE:-Alerte}"
PROJECT_NAME="${PROJECT_NAME:-High-Fortress User}"
MODULE_NAME="${MODULE_NAME:-alerte}"

detail="$(printf '%s' "${CONTENT:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if [[ -z "${detail}" || -z "${WATCHDOG_MAIL:-}" ]]; then
    echo "Mail non envoyé (${MODULE_NAME}) : destinataire ou corps vide." >&2
    exit 0
fi
if ! command -v mail >/dev/null 2>&1; then
    echo "Mail non envoyé (${MODULE_NAME}) : commande mail absente." >&2
    exit 0
fi

export TITLE PROJECT_NAME HOSTNAME DATE MODULE_NAME
CONTENT="${detail}"
export CONTENT
export NOTE="${NOTE:-}"
export NOTE_CMD="${NOTE_CMD:-}"

MAIL_CONTENT="$(python3 - << PY
import html, os, re
from pathlib import Path
tpl = Path(${SCRIPT_DIR@Q}, "mail.html").read_text(encoding="utf-8")
for key in ("TITLE", "PROJECT_NAME", "HOSTNAME", "DATE", "MODULE_NAME"):
    tpl = tpl.replace("\${" + key + "}", html.escape(os.environ.get(key, ""), quote=False))
tpl = tpl.replace("\${CONTENT}", html.escape(os.environ.get("CONTENT", ""), quote=False))
note = os.environ.get("NOTE", "").strip()
note_cmd = os.environ.get("NOTE_CMD", "").strip()
if note and note_cmd:
    tpl = tpl.replace("\${NOTE}", html.escape(note, quote=False))
    tpl = tpl.replace("\${NOTE_CMD}", html.escape(note_cmd, quote=False))
else:
    tpl = re.sub(r"<!--NOTE_START-->.*?<!--NOTE_END-->", "", tpl, count=1, flags=re.S)
print(tpl, end="")
PY
)"

if ! printf '%s' "${MAIL_CONTENT}" | grep -q '<pre'; then
    echo "Mail non envoyé (${MODULE_NAME}) : modèle HTML invalide." >&2
    exit 0
fi

printf '%s\n' "${MAIL_CONTENT}" | mail -s "${PROJECT_NAME} - ${HOSTNAME} - ${MODULE_NAME}" \
    -a "Content-Type: text/html; charset=UTF-8" \
    "${WATCHDOG_MAIL}"
