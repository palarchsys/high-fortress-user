#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/boot-scan.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Enchaîne AIDE, rkhunter, chkrootkit, ClamAV puis debsums
#   après le démarrage. Le service systemd qui lance ce script
#   limite le processeur et les entrées-sorties pour toute la passe.
#   ClamAV saute les dossiers déjà surveillés en continu.
# =============================================================================

set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for scan in aide.sh rkhunter.sh chkrootkit.sh clamav.sh debsums.sh; do
    if [[ -x "${HERE}/${scan}" ]]; then
        bash "${HERE}/${scan}" || true
    fi
done
