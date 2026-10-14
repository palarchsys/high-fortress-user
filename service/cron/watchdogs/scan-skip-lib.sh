#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/watchdogs/scan-skip-lib.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
HFU_SCAN_SKIP_FILE="${HFU_BASE}/cron/scan-skip.paths"

hfu_scan_skip_norm() {
    python3 - "$1" << 'PY'
import os
import sys
raw = sys.argv[1].strip()
if not raw.startswith("/"):
    sys.exit(1)
print(os.path.normpath(raw))
PY
}

hfu_scan_skip_forbidden() {
    printf '%s\n' / /home /opt /tmp /etc /usr /var /boot /root
    if [[ -f /etc/clamav/clamd.conf ]]; then
        awk '/^OnAccessIncludePath[[:space:]]/{print $2}' /etc/clamav/clamd.conf
    fi
}

hfu_scan_skip_home() {
    local line trimmed home homes=""
    if [[ "${HFU_SCAN_SKIP_HOME:-}" =~ ^/home/[^/]+$ ]]; then
        printf '%s\n' "${HFU_SCAN_SKIP_HOME}"
        return 0
    fi
    [[ -f "${HFU_SCAN_SKIP_FILE}" ]] || return 1
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" =~ ^[[:space:]]*#[[:space:]]*home=(/home/[^/]+)[[:space:]]*$ ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
    done < "${HFU_SCAN_SKIP_FILE}"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        [[ -z "${trimmed}" || "${trimmed}" == \#* ]] && continue
        if [[ "${trimmed}" =~ ^(/home/[^/]+)/ ]]; then
            home="${BASH_REMATCH[1]}"
            case "${homes}" in
                *"|${home}|"*) ;;
                *) homes="${homes}|${home}|" ;;
            esac
        fi
    done < "${HFU_SCAN_SKIP_FILE}"
    homes="${homes#|}"
    homes="${homes%|}"
    [[ -n "${homes}" && "${homes}" != *"|"* ]] || return 1
    printf '%s\n' "${homes}"
}

hfu_scan_skip_accept() {
    local norm bad home=""
    norm="$(hfu_scan_skip_norm "$1")" || return 1
    home="$(hfu_scan_skip_home || true)"
    if [[ "${norm}" == /var/jeux || "${norm}" == /var/jeux/* ]]; then
        :
    elif [[ -n "${home}" && "${norm}" == "${home}/"* ]]; then
        :
    else
        return 1
    fi
    while IFS= read -r bad; do
        [[ -z "${bad}" ]] && continue
        [[ "${norm}" == "${bad}" ]] && return 1
        [[ "${bad}" == "${norm}/"* ]] && return 1
    done < <(hfu_scan_skip_forbidden)
    [[ "${norm}" =~ ^/home/[^/]+$ ]] && return 1
    printf '%s\n' "${norm}"
}

hfu_scan_skip_collect() {
    HFU_SCAN_SKIP_OK=()
    HFU_SCAN_SKIP_BAD=()
    [[ -f "${HFU_SCAN_SKIP_FILE}" ]] || return 0
    local line norm seen="|"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        if norm="$(hfu_scan_skip_accept "${line}")"; then
            [[ "${seen}" == *"|${norm}|"* ]] && continue
            seen="${seen}${norm}|"
            HFU_SCAN_SKIP_OK+=("${norm}")
        else
            HFU_SCAN_SKIP_BAD+=("${line}")
        fi
    done < "${HFU_SCAN_SKIP_FILE}"
}

hfu_scan_skip_ensure_file() {
    local home="$1"
    [[ -f "${HFU_SCAN_SKIP_FILE}" ]] && return 0
    [[ "${home}" =~ ^/home/[^/]+$ && -d "${home}" ]] || return 1
    install -d -m 755 "${HFU_BASE}/cron"
    cat > "${HFU_SCAN_SKIP_FILE}" << EOF
# Chemins exclus du scan bloquant et de la passe de démarrage.
# home=${home}
# Un chemin sous ce home, ou sous /var/jeux. Brave, Thunderbird et Discord restent analysés.
# sudo bash ${HFU_BASE}/bin/scan-skip.sh list
# sudo bash ${HFU_BASE}/bin/scan-skip.sh add /chemin
# sudo bash ${HFU_BASE}/bin/scan-skip.sh del /chemin
${home}/.steam
${home}/.local/share/Steam
${home}/.cache
${home}/snap
/var/jeux
EOF
    chmod 644 "${HFU_SCAN_SKIP_FILE}"
    chown root:root "${HFU_SCAN_SKIP_FILE}"
}
