#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/apply-scan-skip.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/scan-skip-lib.sh"

hfu_scan_skip_collect
if [[ ${#HFU_SCAN_SKIP_BAD[@]} -gt 0 ]]; then
    install -d -m 750 "${HFU_BASE}/cron/security_logs"
    for line in "${HFU_SCAN_SKIP_BAD[@]}"; do
        printf '%s chemin refusé : %s\n' "$(date -Iseconds)" "${line}" | tee -a "${HFU_BASE}/cron/security_logs/scan-skip.log"
    done
fi

conf="/etc/clamav/clamd.conf"
if [[ -f "${conf}" ]]; then
    tmp="$(mktemp)"
    trap 'rm -f "${tmp}"' EXIT
    changed="$(python3 - "${conf}" "${tmp}" "${HFU_SCAN_SKIP_OK[@]}" << 'PY'
import sys
from pathlib import Path

conf = Path(sys.argv[1])
dest = Path(sys.argv[2])
paths = sys.argv[3:]
text = conf.read_text(errors="replace")
begin = "# BEGIN High-Fortress User scan-skip"
end = "# END High-Fortress User scan-skip"
out = []
skipping = False
for line in text.splitlines():
    stripped = line.strip()
    if stripped == begin:
        skipping = True
        continue
    if skipping:
        if stripped == end:
            skipping = False
        continue
    if line.startswith("OnAccessExcludePath "):
        continue
    out.append(line)
while out and out[-1] == "":
    out.pop()
block = [begin]
for path in paths:
    block.append(f"OnAccessExcludePath {path}")
block.append(end)
out.append("")
out.extend(block)
new = "\n".join(out) + "\n"
old = text if text.endswith("\n") else text + "\n"
dest.write_text(new)
print("changed" if new != old else "same")
PY
)"
    if [[ "${changed}" == "changed" ]]; then
        cat "${tmp}" > "${conf}"
        if systemctl is-active --quiet clamav-daemon 2>/dev/null; then
            systemctl reload clamav-daemon 2>/dev/null || systemctl restart clamav-daemon
        fi
    fi
    rm -f "${tmp}"
    trap - EXIT
fi

rk="/etc/rkhunter.conf.local"
if [[ -f "${rk}" && ${#HFU_SCAN_SKIP_OK[@]} -gt 0 ]]; then
    for path in "${HFU_SCAN_SKIP_OK[@]}"; do
        case "${path}" in
            */.*)
                grep -qxF "ALLOWHIDDENDIR=${path}" "${rk}" \
                    || printf 'ALLOWHIDDENDIR=%s\n' "${path}" >> "${rk}"
                ;;
        esac
    done
fi
exit 0
