#!/usr/bin/env bash

# Suite 01 — bash -n du poste, du core, des agents et des scripts privés.

hf_section "bash -n"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"
while IFS= read -r file; do
    rel="${file#"${MONO}/"}"
    if bash -n "${file}" 2>"${HF_ARTIFACTS}/bash-n.err"; then
        hf_pass "syntax:${rel}" "bash -n"
    else
        hf_fail "syntax:${rel}" "$(tr '\n' ' ' < "${HF_ARTIFACTS}/bash-n.err")"
    fi
done < <(find "${HF_ROOT}" "${MONO}/core" "${MONO}/agents" "${MONO}/scripts" \
    -name '*.sh' -type f \
    -not -path '*/test/output/*' \
    -not -path '*/node_modules/*' | sort)
