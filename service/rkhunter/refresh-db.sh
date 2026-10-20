#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/refresh-db.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lancez cette commande avec sudo.\n' >&2
    exit 1
fi
if ! command -v rkhunter >/dev/null 2>&1; then
    printf 'rkhunter est absent.\n' >&2
    exit 1
fi
printf 'Calcul de la base de propriétés rkhunter.\n'
set +e
rkhunter --propupd --nocolors
rc=$?
set -e
if [[ "${rc}" -ne 0 ]]; then
    printf 'rkhunter --propupd a retourné le code %s.\n' "${rc}" >&2
    exit 1
fi
printf 'Base de propriétés rkhunter enregistrée.\n'
