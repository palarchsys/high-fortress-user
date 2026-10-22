#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/clamav.sh
# Updated at : 2026-10-21
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Boot and periodic ClamAV walk of /home, /opt and /tmp.
# Note       : HF_CLAM_MODE=daemon selects the running daemon in the shared scanner.
# Note       : The file list is created under /run/high-fortress-user.
# Note       : An anchored OnAccessExcludePath is pruned as its path.
# Note       : HFU_CLAMAV_DEFER=1 skips the pass while a game is running.
# -----------------------------------------------------------------------------

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

install -d -m 755 /run/high-fortress-user
exec 9>/run/high-fortress-user/clamav.lock
if ! flock -n 9; then
    hfu_log_pass "analyse ClamAV déjà en cours"
    exit 0
fi

if [[ "${HFU_CLAMAV_DEFER:-0}" == "1" ]]; then
    busy=""
    for name in lutris heroic gamescope; do
        if pgrep -x "${name}" >/dev/null 2>&1; then
            busy="${name}"
            break
        fi
    done
    if [[ -n "${busy}" ]]; then
        hfu_log_pass "analyse ClamAV reportée : ${busy} tourne"
        exit 0
    fi
fi

if [[ -S /run/clamav/clamd.ctl || -S /var/run/clamav/clamd.ctl ]]; then
    HF_CLAM_MODE=daemon
    export HF_CLAM_MODE
fi

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/scan-skip-lib.sh"
hfu_collect_scan_skip_path

excludes=()
if [[ -f /etc/clamav/clamd.conf ]]; then
    while read -r path; do
        [[ -n "${path}" ]] && excludes+=("${path}")
    done < <(awk '/^OnAccessExcludePath[[:space:]]/{
        p = $2
        sub(/^\^/, "", p)
        sub(/\$$/, "", p)
        gsub(/\\/, "", p)
        print p
    }' /etc/clamav/clamd.conf)
fi

prune_names=(
    proc sys dev
    var/lib/libvirt var/lib/docker
    libvirt
    snap-private-tmp
)

find_args=()
for path in "${excludes[@]}"; do
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

file_list="$(mktemp -p /run/high-fortress-user)"
trap 'rm -f "${file_list}"' EXIT
find /home /opt /tmp \
    \( "${find_args[@]}" \) -prune -o -type f ! -size +25M -print0 \
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
    mapfile -t found_lines < <(grep ' FOUND$' "${LOG_FILE}" || true)
    response="${HERE}/clamav-response.sh"
    [[ -x "${HFU_BASE}/cron/bin/clamav-response.sh" ]] && response="${HFU_BASE}/cron/bin/clamav-response.sh"
    for line in "${found_lines[@]+"${found_lines[@]}"}"; do
        body="${line% FOUND}"
        virus="${body##*: }"
        origin="${body%:*}"
        [[ -n "${origin}" && -n "${virus}" ]] || continue
        HFU_CLAMAV_EVENT_FILE="${origin}" \
        HFU_CLAMAV_EVENT_VIRUS="${virus}" \
        HFU_CLAMAV_EVENT_KIND=periodic \
        HFU_CLAMAV_EVENT_MAIL=0 \
        HFU_CLAMAV_RESPONSE_STAMP="${STAMP}-$$" \
            bash "${response}" || true
    done
    hf_log_alert "clamscan : infection(s) (voir ${LOG_FILE})"
elif [[ "${kind}" == "error" ]]; then
    hf_log_alert "clamscan erreur rc=${rc}"
elif ! grep -q 'clamscan planté signal' "${LOG_FILE}"; then
    hfu_log_pass "clamscan OK"
fi
exit 0
