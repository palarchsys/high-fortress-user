#!/usr/bin/env bash
# =============================================================================
# File       : core/config-validators.sh
# Updated at : 2026-10-26
# Creator    : palarchsys
# =============================================================================

hf_check_email() {
    [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]
}

hf_check_port() {
    local min="$2" max="$3"
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    (( 10#$1 >= min && 10#$1 <= max )) || return 1
    return 0
}

hf_check_smtp() {
    local host port
    [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?:[0-9]+$ ]] || return 1
    host="${1%:*}"
    port="${1##*:}"
    [[ "${host}" != *..* && "${host}" != .* && "${host}" != *. ]] || return 1
    hf_check_port "${port}" 1 65535
}

hf_check_absolute_path() {
    [[ "$1" =~ ^/[A-Za-z0-9._/-]+$ && "$1" != *..* ]]
}

hf_check_drive_remote() {
    [[ "$1" =~ ^[A-Za-z0-9-]{1,32}$ ]]
}

hf_check_drive_path() {
    local value="$1"
    [[ -n "${value}" ]] || return 1
    [[ "${value}" != /* ]] || return 1
    [[ "${value}" != *..* ]] || return 1
    [[ "${value}" != *:* ]] || return 1
    [[ "${value}" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$ ]] || return 1
    [[ "${value}" != */ ]] || return 1
    return 0
}

hf_check_drive_probe() {
    local remote="$1" path="$2" config="$3"
    local probe err
    [[ -n "${remote}" && -n "${path}" && -f "${config}" ]] || return 1
    command -v rclone >/dev/null 2>&1 || return 1
    probe="$(mktemp)"
    err="$(mktemp)"
    printf '%s\n' "high-fortress" > "${probe}"
    if RCLONE_CONFIG="${config}" rclone mkdir "${remote}:${path}" >"${err}" 2>&1 \
        && RCLONE_CONFIG="${config}" rclone copyto "${probe}" "${remote}:${path}/high-fortress-probe.txt" >"${err}" 2>&1 \
        && RCLONE_CONFIG="${config}" rclone deletefile "${remote}:${path}/high-fortress-probe.txt" >"${err}" 2>&1; then
        rm -f "${probe}" "${err}"
        return 0
    fi
    rm -f "${probe}" "${err}"
    return 1
}

hf_check_app_password() {
    local value="$1" i c tick=$'\x60'
    [[ "${#value}" -ge 8 && "${#value}" -le 128 ]] || return 1
    for ((i = 0; i < ${#value}; i++)); do
        c="${value:i:1}"
        case "${c}" in
            [[:space:]] | '"' | "'" | '$' | '\' | "${tick}")
                return 1
                ;;
        esac
    done
    return 0
}
