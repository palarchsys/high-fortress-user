#!/usr/bin/env bash
# =============================================================================
# File       : core/config-validators.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

hf_is_email() {
    [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]
}

hf_is_port() {
    local min="$2" max="$3"
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    (( 10#$1 >= min && 10#$1 <= max )) || return 1
    return 0
}

hf_is_smtp() {
    local host port
    [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?:[0-9]+$ ]] || return 1
    host="${1%:*}"
    port="${1##*:}"
    [[ "${host}" != *..* && "${host}" != .* && "${host}" != *. ]] || return 1
    hf_is_port "${port}" 1 65535
}

hf_is_abs_path() {
    [[ "$1" =~ ^/[A-Za-z0-9._/-]+$ && "$1" != *..* ]]
}

hf_is_app_password() {
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

hfu_is_email() { hf_is_email "$@"; }
hfu_is_port() { hf_is_port "$@"; }
hfu_is_smtp() { hf_is_smtp "$@"; }
hfu_is_abs_path() { hf_is_abs_path "$@"; }

hfu_is_secret() { hf_is_app_password "$@"; }
