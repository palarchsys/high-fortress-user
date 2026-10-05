#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/send.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
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

_mail_sh=""
for _candidate in \
    "${CONFIG_BASE_DIR:-}/src/core/mail.sh" \
    "${DIR_INSTALL_PATH:-}/core/mail.sh" \
    "${DIR_INSTALL_PATH:-}/../core/mail.sh" \
    "${SCRIPT_DIR}/../../../core/mail.sh" \
    "${SCRIPT_DIR}/../../../../core/mail.sh" \
    "${SCRIPT_DIR}/../core/mail.sh" \
    "${SCRIPT_DIR}/../../core/mail.sh" \
    "${SCRIPT_DIR}/../../src/core/mail.sh"
do
    if [[ -n "${_candidate}" && -f "${_candidate}" ]]; then
        _mail_sh="${_candidate}"
        break
    fi
done
if [[ -z "${_mail_sh}" ]]; then
    echo "Mail non envoyé (${MODULE_NAME}) : core/mail.sh introuvable." >&2
    exit 0
fi
# shellcheck disable=SC1090
source "${_mail_sh}"

tpl="$(hf_mail_template_file "${SCRIPT_DIR}")" || {
    echo "Mail non envoyé (${MODULE_NAME}) : modèle HTML introuvable." >&2
    exit 0
}
if ! MAIL_CONTENT="$(hf_render_mail "${tpl}")"; then
    echo "Mail non envoyé (${MODULE_NAME}) : modèle HTML invalide." >&2
    exit 0
fi

printf '%s\n' "${MAIL_CONTENT}" | mail -s "${PROJECT_NAME} - ${HOSTNAME} - ${MODULE_NAME}" \
    -a "Content-Type: text/html; charset=UTF-8" \
    "${WATCHDOG_MAIL}"
