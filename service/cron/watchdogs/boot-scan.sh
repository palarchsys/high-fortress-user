#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/boot-scan.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for scan in aide.sh rkhunter.sh chkrootkit.sh clamav.sh debsums.sh; do
    if [[ -x "${HERE}/${scan}" ]]; then
        bash "${HERE}/${scan}" || true
    fi
done
