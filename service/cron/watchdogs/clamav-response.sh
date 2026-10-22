#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/clamav-response.sh
# Updated at : 2026-10-22
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Quarantine one detection and record the actions.
# Note       : Logs stay under the High-Fortress cron directories or /run.
# Note       : A detection signals one non-critical holder.
# Note       : A detection isolates new outbound flows for HFU_NET_ISOLATE_SEC seconds.
# -----------------------------------------------------------------------------

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
if [[ -z "${LOG_FILE:-}" ]]; then
    LOG_FILE="${LOG_DIR}/clamav-response-${STAMP}.log"
fi
if [[ -f "${HFU_BASE}/cron/egress.conf" ]]; then
    # shellcheck disable=SC1091
    source "${HFU_BASE}/cron/egress.conf"
fi

file="${HFU_CLAMAV_EVENT_FILE:-${CLAM_VIRUSEVENT_FILENAME:-inconnu}}"
virus="${HFU_CLAMAV_EVENT_VIRUS:-${CLAM_VIRUSEVENT_VIRUSNAME:-inconnu}}"
kind="${HFU_CLAMAV_EVENT_KIND:-onaccess}"
case "${kind}" in
    periodic) kind_label="scan périodique" ;;
    idle) kind_label="passe différée" ;;
    *) kind_label="accès" ;;
esac
action_quarantine="quarantaine non appliquée"
action_process="processus non arrêté : aucun détenteur"
action_network="isolation non appliquée"
stored="inconnue"

hfu_check_clamav_denied() {
    local comm="$1"
    local name
    [[ -n "${comm}" ]] || return 1
    for name in systemd sshd unbound fail2ban gamescope; do
        [[ "${comm}" == "${name}" || "${comm}" == "${name}"* ]] && return 0
    done
    return 1
}

hfu_apply_clamav_quarantine() {
    local quarantine base stamp dest
    quarantine="${HFU_CLAMAV_QUARANTINE_DIR:-/var/lib/clamav/quarantine}"
    if id clamav >/dev/null 2>&1; then
        install -d -m 750 -o clamav -g clamav "${quarantine}"
    else
        install -d -m 750 "${quarantine}"
    fi
    base="$(basename -- "${file}")"
    [[ -n "${base}" && "${base}" != "/" ]] || base="inconnu"
    stamp="$(date +%Y%m%d-%H%M%S-%N)"
    dest="${quarantine}/${stamp}-${base}"
    stored="${dest}"
    if [[ "${file}" == "${quarantine}/"* && -e "${file}" ]]; then
        if [[ "${base}" =~ ^[0-9]{8}-[0-9]{6}- ]]; then
            stored="${file}"
            action_quarantine="déjà en quarantaine"
            return 0
        fi
        if mv -- "${file}" "${dest}"; then
            action_quarantine="renommé en quarantaine"
        else
            stored="${file}"
            action_quarantine="renommage refusé"
        fi
        return 0
    fi
    if [[ -e "${file}" ]]; then
        if mv -- "${file}" "${dest}"; then
            action_quarantine="déplacé en quarantaine"
        else
            stored="${file}"
            action_quarantine="déplacement refusé"
        fi
        return 0
    fi
    if [[ -e "${quarantine}/${base}" ]]; then
        if mv -- "${quarantine}/${base}" "${dest}"; then
            action_quarantine="renommé en quarantaine"
        else
            stored="${quarantine}/${base}"
            action_quarantine="renommage refusé"
        fi
        return 0
    fi
    stored="absent"
    action_quarantine="fichier déjà absent"
}

hfu_read_clamav_holder() {
    local target="$1"
    local pid=""
    if command -v lsof >/dev/null 2>&1; then
        pid="$(lsof -t -- "${target}" 2>/dev/null | head -n 1 || true)"
    fi
    if [[ -z "${pid}" ]] && command -v fuser >/dev/null 2>&1; then
        pid="$(fuser -- "${target}" 2>/dev/null | awk '{print $1; exit}' || true)"
    fi
    printf '%s\n' "${pid}"
}

hfu_signal_clamav_holder() {
    local target pid comm uid
    action_process="processus non arrêté : aucun détenteur"
    for target in "${file}" "${stored}"; do
        [[ -n "${target}" && "${target}" != "absent" && "${target}" != "inconnue" && -e "${target}" ]] || continue
        pid="$(hfu_read_clamav_holder "${target}")"
        [[ -n "${pid}" && "${pid}" =~ ^[0-9]+$ ]] || continue
        if [[ "${pid}" == "1" ]]; then
            action_process="processus non arrêté : pid 1"
            return 0
        fi
        uid="$(stat -c '%u' "/proc/${pid}" 2>/dev/null || echo 0)"
        if [[ "${uid}" == "0" ]]; then
            action_process="processus non arrêté : uid 0"
            return 0
        fi
        comm="$(cat "/proc/${pid}/comm" 2>/dev/null || true)"
        if hfu_check_clamav_denied "${comm}"; then
            action_process="processus non arrêté : ${comm}"
            return 0
        fi
        if [[ -z "${comm}" ]]; then
            action_process="processus non arrêté : nom absent"
            return 0
        fi
        if kill -TERM "${pid}" 2>/dev/null; then
            action_process="processus ${pid} (${comm}) arrêté"
        else
            action_process="processus ${pid} non arrêté : signal refusé"
        fi
        return 0
    done
}

hfu_apply_net_isolate() {
    local sec
    sec="${HFU_NET_ISOLATE_SEC:-120}"
    if [[ ! "${sec}" =~ ^[0-9]+$ ]] || [[ "${sec}" -lt 30 ]] || [[ "${sec}" -gt 300 ]]; then
        sec=120
    fi
    if ! command -v nft >/dev/null 2>&1; then
        action_network="isolation non appliquée : nft absent"
        return 0
    fi
    nft delete table inet hfu_isolate >/dev/null 2>&1 || true
    nft add table inet hfu_isolate
    nft add chain inet hfu_isolate output '{ type filter hook output priority 0 ; policy accept ; }'
    nft add rule inet hfu_isolate output ct state established,related accept
    nft add rule inet hfu_isolate output ip daddr 127.0.0.0/8 accept
    nft add rule inet hfu_isolate output ip6 daddr ::1 accept
    nft add rule inet hfu_isolate output meta l4proto '{ tcp, udp }' th dport 53 accept
    nft add rule inet hfu_isolate output reject
    if command -v systemd-run >/dev/null 2>&1; then
        systemctl stop hfu-net-release.timer >/dev/null 2>&1 || true
        systemd-run --unit=hfu-net-release --on-active="${sec}" --collect nft delete table inet hfu_isolate >/dev/null 2>&1 \
            || true
        action_network="isolation ${sec}s"
    else
        action_network="isolation posée sans minuteur"
    fi
}

hfu_apply_clamav_quarantine
if declare -F hf_record_quarantine_origin >/dev/null 2>&1; then
    case "${action_quarantine}" in
        "déplacé en quarantaine"|"renommé en quarantaine")
            hf_record_quarantine_origin clamav "${file}" "${stored}" "${virus}" || true
            ;;
        "déjà en quarantaine")
            hf_queue_existing_restore "${stored}" || true
            ;;
    esac
fi
hfu_signal_clamav_holder
hfu_apply_net_isolate

response_stamp="${HFU_CLAMAV_RESPONSE_STAMP:-${STAMP}}"
printf '%s\n' "${stored}" > "${LOG_DIR}/clamav-response-${response_stamp}.path"
printf '%s\n' \
    "Date : $(date -Iseconds)" \
    "Type : ${kind_label}" \
    "Signature : ${virus}" \
    "Fichier : $(basename -- "${file}")" \
    "Emplacement d'origine : ${file}" \
    "Actions : ${action_quarantine} ; ${action_process} ; ${action_network}" \
    "Quarantaine : ${stored}" \
    "Recommandation : Ne remettez pas ce fichier en place. Lisez le journal avant toute autre action." \
    >> "${LOG_FILE}"
logger -t high-fortress-user -p auth.warning \
    "ClamAV ${virus} type=${kind_label} origine=${file} quarantaine=${stored} actions=${action_quarantine}"
