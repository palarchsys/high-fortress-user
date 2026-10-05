#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/01_bash_syntax.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

hf_cartouche_ok() {
    local file="$1"
    local rel="$2"
    local start=1
    local bar='# ============================================================================='
    local l1 l2 l3 l4 l5
    [[ "$(head -n 1 "${file}")" == \#!* ]] && start=2
    l1="$(sed -n "${start}p" "${file}")"
    l2="$(sed -n "$((start + 1))p" "${file}")"
    l3="$(sed -n "$((start + 2))p" "${file}")"
    l4="$(sed -n "$((start + 3))p" "${file}")"
    l5="$(sed -n "$((start + 4))p" "${file}")"
    [[ "${l1}" == "${bar}" && "${l5}" == "${bar}" ]] || return 1
    [[ "${l2}" == "$(printf '# %-11s: %s' File "${rel}")" ]] || return 1
    [[ "${l3}" =~ ^'# Updated at : '[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
    [[ "${l4}" == "$(printf '# %-11s: %s' Creator palarchsys)" ]] || return 1
}

hf_section "bash -n"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"
while IFS= read -r file; do
    rel="${file#"${MONO}/"}"
    if [[ "${file}" == "${HF_ROOT}/"* ]]; then
        cart_rel="${file#"${HF_ROOT}/"}"
    else
        cart_rel="${rel}"
    fi
    if hf_cartouche_ok "${file}" "${cart_rel}"; then
        hf_pass "syntax.cartouche:${rel}" "cartouche"
    else
        hf_fail "syntax.cartouche:${rel}" "cartouche absent ou différent de la loi style"
    fi
    if bash -n "${file}" 2>"${HF_ARTIFACTS}/bash-n.err"; then
        hf_pass "syntax:${rel}" "bash -n"
    else
        hf_fail "syntax:${rel}" "$(tr '\n' ' ' < "${HF_ARTIFACTS}/bash-n.err")"
    fi
done < <(find "${HF_ROOT}" "${MONO}/core" "${MONO}/agents" "${MONO}/scripts" \
    -name '*.sh' -type f \
    -not -path '*/test/output/*' \
    -not -path '*/node_modules/*' | sort)
