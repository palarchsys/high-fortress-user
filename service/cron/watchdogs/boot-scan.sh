#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/boot-scan.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "${HERE}/apply-scan-skip.sh" ]]; then
    bash "${HERE}/apply-scan-skip.sh" || true
fi
for scan in aide.sh rkhunter.sh chkrootkit.sh clamav.sh debsums.sh; do
    if [[ -x "${HERE}/${scan}" ]]; then
        bash "${HERE}/${scan}" || true
    fi
done
