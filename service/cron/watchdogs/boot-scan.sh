#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/boot-scan.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Enchaîne AIDE, rkhunter, chkrootkit puis ClamAV après le démarrage.
#   Le service systemd qui lance ce script limite le processeur.
#   ClamAV saute les dossiers déjà surveillés en continu.
# =============================================================================

set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for scan in aide.sh rkhunter.sh chkrootkit.sh clamav.sh; do
    if [[ -x "${HERE}/${scan}" ]]; then
        bash "${HERE}/${scan}" || true
    fi
done
