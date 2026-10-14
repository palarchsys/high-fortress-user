#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/idle-scan.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
# shellcheck disable=SC1091
source "${HERE}/scan-skip-lib.sh"
LOG_FILE="${LOG_DIR}/idle-scan-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/idle-scan-${STAMP}.txt"
: > "${LOG_FILE}"

busy=""
for name in steam steamwebhelper lutris heroic wineserver gamescope; do
    if pgrep -x "${name}" >/dev/null 2>&1; then
        busy="${name}"
        break
    fi
done
if [[ -n "${busy}" ]]; then
    log_ok "passe différée reportée : ${busy} tourne"
    exit 0
fi

if ! command -v clamscan >/dev/null; then
    log_ok "clamscan absent — skip"
    exit 0
fi

hfu_scan_skip_collect
file_list="$(mktemp)"
trap 'rm -f "${file_list}"' EXIT
stamp="${HFU_BASE}/cron/scan-skip.stamp"
if [[ ${#HFU_SCAN_SKIP_OK[@]} -gt 0 ]]; then
    for path in "${HFU_SCAN_SKIP_OK[@]}"; do
        base="$(basename "${path}")"
        [[ "${base}" == ".cache" || "${base}" == "snap" ]] && continue
        [[ -e "${path}" ]] || continue
        if [[ -f "${path}" ]]; then
            printf '%s\0' "${path}" >> "${file_list}"
            continue
        fi
        [[ -d "${path}" ]] || continue
        if [[ -f "${stamp}" ]]; then
            find "${path}" \
                \( -path '*/shadercache' -o -path '*/shadercache/*' \
                    -o -path '*/downloading' -o -path '*/downloading/*' \) -prune -o \
                -type f \( -perm /111 -o \( ! -size +25M -newer "${stamp}" \) \) -print0 \
                >> "${file_list}" 2>>"${LOG_FILE}" || true
        else
            find "${path}" \
                \( -path '*/shadercache' -o -path '*/shadercache/*' \
                    -o -path '*/downloading' -o -path '*/downloading/*' \) -prune -o \
                -type f \( -perm /111 -o ! -size +25M \) -print0 \
                >> "${file_list}" 2>>"${LOG_FILE}" || true
        fi
    done
fi

set +e
if [[ -s "${file_list}" ]]; then
    xargs -0 -r -n 80 clamscan --infected < "${file_list}" >> "${LOG_FILE}" 2>&1
    rc=$?
    if [[ "${rc}" -eq 123 ]] && grep -q 'FOUND' "${LOG_FILE}"; then
        rc=1
    fi
else
    rc=0
fi
set -e

seen="${HFU_BASE}/cron/scan-skip.seen"
if [[ "${rc}" -ge 2 ]]; then
    log_alert "clamscan erreur rc=${rc}"
    exit 0
fi
if [[ "${rc}" -eq 1 ]]; then
    new_count="$(python3 - "${LOG_FILE}" "${seen}" << 'PY'
import sys
from pathlib import Path

log = Path(sys.argv[1]).read_text(errors="replace").splitlines()
seen_path = Path(sys.argv[2])
known = set()
if seen_path.is_file():
    known = {line for line in seen_path.read_text(errors="replace").splitlines() if line}
fresh = []
for line in log:
    if not line.endswith(" FOUND"):
        continue
    body = line[:-6]
    if ": " not in body:
        continue
    path, sig = body.rsplit(": ", 1)
    key = sig + "\t" + path
    if key in known or key in fresh:
        continue
    fresh.append(key)
if fresh:
    with seen_path.open("a", encoding="utf-8") as handle:
        for key in fresh:
            handle.write(key + "\n")
print(len(fresh))
PY
)"
    chmod 600 "${seen}" 2>/dev/null || true
    if [[ "${new_count}" -gt 0 ]]; then
        log_alert "clamscan : infection(s) (voir ${LOG_FILE})"
    else
        log_ok "infections déjà signalées"
    fi
    exit 0
fi

touch "${stamp}"
chmod 644 "${stamp}"
log_ok "clamscan OK"
exit 0
