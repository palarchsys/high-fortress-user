#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/scan-skip.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/scan-skip-lib.sh"

hfu_show_usage() {
    printf 'Usage : sudo bash %s/bin/scan-skip.sh list\n' "${HFU_BASE}" >&2
    printf '       sudo bash %s/bin/scan-skip.sh add /chemin\n' "${HFU_BASE}" >&2
    printf '       sudo bash %s/bin/scan-skip.sh del /chemin\n' "${HFU_BASE}" >&2
}

if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lancez cette commande avec sudo.\n' >&2
    exit 1
fi

action="${1:-}"
case "${action}" in
    list|add|del) ;;
    *)
        hfu_show_usage
        exit 1
        ;;
esac

if [[ ! -f "${HFU_SCAN_SKIP_FILE}" ]]; then
    printf 'Fichier absent : %s\n' "${HFU_SCAN_SKIP_FILE}" >&2
    exit 1
fi

if [[ "${action}" == "list" ]]; then
    hfu_collect_scan_skip_path
    if [[ ${#HFU_SCAN_SKIP_VALID[@]} -gt 0 ]]; then
        printf '%s\n' "${HFU_SCAN_SKIP_VALID[@]}"
    fi
    if [[ ${#HFU_SCAN_SKIP_BAD[@]} -gt 0 ]]; then
        for line in "${HFU_SCAN_SKIP_BAD[@]}"; do
            printf 'Chemin refusé : %s\n' "${line}" >&2
        done
    fi
    exit 0
fi

if [[ $# -ne 2 ]]; then
    hfu_show_usage
    exit 1
fi

if ! norm="$(hfu_check_scan_skip_path "$2")"; then
    printf 'Chemin refusé : %s\n' "$2" >&2
    exit 1
fi

hfu_collect_scan_skip_path
found=0
if [[ ${#HFU_SCAN_SKIP_VALID[@]} -gt 0 ]]; then
    for path in "${HFU_SCAN_SKIP_VALID[@]}"; do
        [[ "${path}" == "${norm}" ]] && found=1
    done
fi

if [[ "${action}" == "add" ]]; then
    if [[ "${found}" -eq 1 ]]; then
        printf 'Ce chemin est déjà exclu : %s\n' "${norm}"
        exit 0
    fi
    if [[ -s "${HFU_SCAN_SKIP_FILE}" ]] && [[ "$(tail -c1 "${HFU_SCAN_SKIP_FILE}" | wc -l)" -eq 0 ]]; then
        printf '\n' >> "${HFU_SCAN_SKIP_FILE}"
    fi
    printf '%s\n' "${norm}" >> "${HFU_SCAN_SKIP_FILE}"
    printf 'Chemin ajouté : %s\n' "${norm}"
else
    if [[ "${found}" -eq 0 ]]; then
        printf 'Ce chemin n'\''est pas dans la liste : %s\n' "${norm}" >&2
        exit 1
    fi
    python3 - "${HFU_SCAN_SKIP_FILE}" "${norm}" << 'PY'
import sys
from pathlib import Path

dest = Path(sys.argv[1])
target = sys.argv[2]
kept = []
for raw in dest.read_text(errors="replace").splitlines():
    line = raw.strip()
    if line == target:
        continue
    kept.append(raw)
text = "\n".join(kept)
if text and not text.endswith("\n"):
    text += "\n"
if not text.endswith("\n"):
    text += "\n"
dest.write_text(text)
PY
    printf 'Chemin retiré : %s\n' "${norm}"
fi

bash "${HFU_BASE}/cron/bin/apply-scan-skip.sh"
exit 0
