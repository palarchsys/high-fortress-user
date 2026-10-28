#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/scan-skip.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
W_BASE="${W_BASE:-/opt/liltress-workstation}"
# shellcheck disable=SC1091
source "${W_BASE}/cron/bin/scan-skip-lib.sh"

w_show_usage() {
    printf 'Usage : sudo bash %s/bin/scan-skip.sh list\n' "${W_BASE}" >&2
    printf '       sudo bash %s/bin/scan-skip.sh add /chemin\n' "${W_BASE}" >&2
    printf '       sudo bash %s/bin/scan-skip.sh del /chemin\n' "${W_BASE}" >&2
}

if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lancez cette commande avec sudo.\n' >&2
    exit 1
fi

action="${1:-}"
case "${action}" in
    list|add|del) ;;
    *)
        w_show_usage
        exit 1
        ;;
esac

if [[ ! -f "${W_SCAN_SKIP_FILE}" ]]; then
    printf 'Fichier absent : %s\n' "${W_SCAN_SKIP_FILE}" >&2
    exit 1
fi

if [[ "${action}" == "list" ]]; then
    w_collect_scan_skip_path
    if [[ ${#W_SCAN_SKIP_VALID[@]} -gt 0 ]]; then
        printf '%s\n' "${W_SCAN_SKIP_VALID[@]}"
    fi
    if [[ ${#W_SCAN_SKIP_BAD[@]} -gt 0 ]]; then
        for line in "${W_SCAN_SKIP_BAD[@]}"; do
            printf 'Chemin refusé : %s\n' "${line}" >&2
        done
    fi
    exit 0
fi

if [[ $# -ne 2 ]]; then
    w_show_usage
    exit 1
fi

if ! norm="$(w_check_scan_skip_path "$2")"; then
    printf 'Chemin refusé : %s\n' "$2" >&2
    exit 1
fi

w_collect_scan_skip_path
found=0
if [[ ${#W_SCAN_SKIP_VALID[@]} -gt 0 ]]; then
    for path in "${W_SCAN_SKIP_VALID[@]}"; do
        [[ "${path}" == "${norm}" ]] && found=1
    done
fi

if [[ "${action}" == "add" ]]; then
    if [[ "${found}" -eq 1 ]]; then
        printf 'Ce chemin est déjà exclu : %s\n' "${norm}"
        exit 0
    fi
    if [[ -s "${W_SCAN_SKIP_FILE}" ]] && [[ "$(tail -c1 "${W_SCAN_SKIP_FILE}" | wc -l)" -eq 0 ]]; then
        printf '\n' >> "${W_SCAN_SKIP_FILE}"
    fi
    printf '%s\n' "${norm}" >> "${W_SCAN_SKIP_FILE}"
    printf 'Chemin ajouté : %s\n' "${norm}"
else
    if [[ "${found}" -eq 0 ]]; then
        printf 'Ce chemin n'\''est pas dans la liste : %s\n' "${norm}" >&2
        exit 1
    fi
    python3 - "${W_SCAN_SKIP_FILE}" "${norm}" << 'PY'
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

bash "${W_BASE}/cron/bin/apply-scan-skip.sh"
exit 0
