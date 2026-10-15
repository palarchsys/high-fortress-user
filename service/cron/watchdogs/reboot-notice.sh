#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/reboot-notice.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/reboot-notice-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/reboot-notice-${STAMP}.txt"
: > "${LOG_FILE}"
MODULE_NAME="reboot"
hf_arm_crash_mail "avis de redémarrage"

busy=""
for name in steam steamwebhelper lutris heroic wineserver gamescope; do
    if pgrep -x "${name}" >/dev/null 2>&1; then
        busy="${name}"
        break
    fi
done
if [[ -n "${busy}" ]]; then
    hfu_log_pass "avis de redémarrage reporté : ${busy} tourne"
    exit 0
fi

body=""
if [[ -f /var/run/reboot-required ]]; then
    body="$(cat /var/run/reboot-required)"
fi
if [[ -f /var/run/reboot-required.pkgs ]]; then
    body="${body}"$'\n'"$(sed '/^$/d' /var/run/reboot-required.pkgs)"
fi
if command -v fwupdmgr >/dev/null 2>&1; then
    fw=""
    fw_rc=0
    fw="$(timeout 20 fwupdmgr get-updates 2>/dev/null)" || fw_rc=$?
    if [[ "${fw_rc}" -eq 0 && -n "${fw}" ]] && ! grep -qiE 'no updates available|no available firmware updates|no updatable devices' <<< "${fw}"; then
        body="${body}"$'\n'"${fw}"
    fi
fi
body="$(printf '%s' "${body}" | sed '/^$/d')"
if [[ -z "${body}" ]]; then
    hfu_log_pass "aucun redémarrage utile"
    exit 0
fi

seen="${HFU_BASE}/cron/reboot-notice.seen"
digest="$(printf '%s' "${body}" | sha256sum | awk '{print $1}')"
if [[ -f "${seen}" ]] && [[ "$(cat "${seen}")" == "${digest}" ]]; then
    hfu_log_pass "avis de redémarrage déjà envoyé"
    exit 0
fi
printf '%s\n' "${body}" >> "${LOG_FILE}"
hf_log_alert "Un redémarrage est utile. La machine n'a pas été redémarrée."
umask 077
printf '%s\n' "${digest}" > "${seen}"
chmod 600 "${seen}"
