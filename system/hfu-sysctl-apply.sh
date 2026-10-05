#!/usr/bin/env bash
# =============================================================================
# File       : system/hfu-sysctl-apply.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

set -u
conf="/etc/sysctl.d/99-zzz-high-fortress-user.conf"
[[ -f "${conf}" ]] || exit 0
while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "${line}" ]] && continue
    [[ "${line}" == *=* ]] || continue
    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    val="${line#*=}"
    val="${val#"${val%%[![:space:]]*}"}"

    proc="/proc/sys/${key//.//}"
    if [[ ! -e "${proc}" ]]; then
        printf 'ignoré: %s absent\n' "${key}" >&2
        continue
    fi
    err="$(sysctl -w "${key}=${val}" 2>&1)" && continue
    current="$(sysctl -n "${key}" 2>/dev/null || true)"
    if [[ "${current}" == "${val}" ]]; then
        continue
    fi

    printf 'ignoré: %s\n' "${err}" >&2
done < "${conf}"
exit 0
