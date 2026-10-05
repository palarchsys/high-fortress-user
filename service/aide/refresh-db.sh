#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/refresh-db.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lancez cette commande avec sudo.\n' >&2
    exit 1
fi
if [[ ! -f /etc/aide/aide.conf ]]; then
    printf 'Configuration AIDE absente : /etc/aide/aide.conf\n' >&2
    exit 1
fi
printf 'Calcul de la nouvelle base AIDE. Cela peut prendre plusieurs minutes.\n'

rm -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db.new.gz
set +e
aide --config=/etc/aide/aide.conf --init
aide_rc=$?
set -e
if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
    mv -f /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    ln -sfn /var/lib/aide/aide.db.gz /var/lib/aide/aide.db
elif [[ -f /var/lib/aide/aide.db.new ]]; then
    mv -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db
else
    printf 'La nouvelle base n'\''a pas été produite (code %s).\n' "${aide_rc}" >&2
    exit 1
fi
if [[ "${aide_rc}" -ne 0 ]]; then
    printf 'aide --init a retourné le code %s. La base produite est tout de même en service.\n' "${aide_rc}"
fi
printf 'Base de référence AIDE enregistrée.\n'
