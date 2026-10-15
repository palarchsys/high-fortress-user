#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/clamav.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/clamav-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/clamav-${STAMP}.txt"
if ! command -v clamscan >/dev/null; then
    hfu_log_pass "clamscan absent — skip"
    exit 0
fi

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/scan-skip-lib.sh"
hfu_collect_scan_skip_path

onaccess=()
if [[ -f /etc/clamav/clamd.conf ]]; then
    while read -r _ path; do
        [[ -n "${path}" ]] && onaccess+=("${path}")
    done < <(awk '/^OnAccessIncludePath[[:space:]]/{print $1, $2}' /etc/clamav/clamd.conf)
fi

prune_names=(
    proc sys dev
    var/lib/libvirt var/lib/docker
    libvirt
    snap-private-tmp
)

find_args=()
for path in "${onaccess[@]}"; do
    find_args+=( -path "${path}" -o -path "${path}/*" -o )
done
if [[ ${#HFU_SCAN_SKIP_VALID[@]} -gt 0 ]]; then
    for path in "${HFU_SCAN_SKIP_VALID[@]}"; do
        find_args+=( -path "${path}" -o -path "${path}/*" -o )
    done
fi
for name in "${prune_names[@]}"; do
    find_args+=( -path "*/${name}" -o -path "*/${name}/*" -o )
done
unset 'find_args[-1]'

file_list="$(mktemp)"
trap 'rm -f "${file_list}"' EXIT
find /home /opt /tmp \
    \( "${find_args[@]}" \) -prune -o -type f -print0 \
    > "${file_list}" 2>>"${LOG_FILE}" || true

set +e
trap '' PIPE
hf_list_clamav_scan "${file_list}" >> "${LOG_FILE}" 2>&1
rc=$?
trap - PIPE
set -e
kind="$(hf_get_clamav_kind "${LOG_FILE}")"
if [[ "${kind}" == "ok" && "${rc}" -ne 0 ]]; then
    kind="error"
fi

hf_report_clamav || true
if [[ "${kind}" == "infected" ]]; then
    hf_log_alert "clamscan : infection(s) (voir ${LOG_FILE})"
elif [[ "${kind}" == "error" ]]; then
    hf_log_alert "clamscan erreur rc=${rc}"
elif ! grep -q 'clamscan planté signal' "${LOG_FILE}"; then
    hfu_log_pass "clamscan OK"
fi
exit 0
