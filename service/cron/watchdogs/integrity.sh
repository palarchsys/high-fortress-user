#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/integrity.sh
# Updated at : 2026-10-21
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Note       : The stamp lives under the High-Fortress cron directory.
# Note       : The first pass writes the stamp and stays silent.
# -----------------------------------------------------------------------------

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/integrity-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/integrity-${STAMP}.txt"
MODULE_NAME="Integrite"

list=""
for candidate in \
    "${HFU_BASE}/config/integrity/paths.list" \
    "${HFU_BASE}/src/config/integrity/paths.list" \
    "${HF_INSTALL_DIRECTORY:-}/config/integrity/paths.list"
do
    [[ -f "${candidate}" ]] || continue
    list="${candidate}"
    break
done
if [[ -z "${list}" ]]; then
    hfu_log_pass "liste d'intégrité absente"
    exit 0
fi

install -d -m 755 /run/high-fortress-user
current="$(mktemp -p /run/high-fortress-user)"
trap 'rm -f "${current}"' EXIT
stamp="${HFU_BASE}/cron/integrity.sha256"
while read -r path; do
    [[ -n "${path}" && "${path}" != \#* && -f "${path}" ]] || continue
    sha256sum -- "${path}"
done < "${list}" | sort > "${current}"

if [[ ! -s "${stamp}" ]]; then
    install -d -m 750 "${HFU_BASE}/cron"
    cat "${current}" > "${stamp}"
    chmod 600 "${stamp}"
    hfu_log_pass "empreinte initiale écrite"
    exit 0
fi
if cmp -s "${stamp}" "${current}"; then
    hfu_log_pass "intégrité inchangée"
    exit 0
fi
comm -3 "${stamp}" "${current}" >> "${LOG_FILE}" || true
cat "${current}" > "${stamp}"
chmod 600 "${stamp}"
hf_log_alert "intégrité : empreinte modifiée"
exit 0
