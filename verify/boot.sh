#!/usr/bin/env bash
# =============================================================================
# File       : verify/boot.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lancez cette commande avec sudo.\n' >&2
    exit 1
fi

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${here}/../service/cron/boot-check.sh"
