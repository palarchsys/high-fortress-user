#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/07_router.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

hf_section "routeur"
root=""
here="${HF_ROOT}"
while [[ "${here}" != "/" ]]; do
    if [[ -f "${here}/agents/route.sh" ]]; then
        root="${here}"
        break
    fi
    here="$(dirname -- "${here}")"
done

if [[ -z "${root}" ]]; then
    hf_fail "route.check" "agents/route.sh introuvable au-dessus de ${HF_ROOT}"
elif bash "${root}/agents/route.sh" --check > "${HF_ARTIFACTS}/route.txt"; then
    hf_pass "route.check" "fichiers cités présents"
else
    hf_fail "route.check" "$(tr '\n' ' ' < "${HF_ARTIFACTS}/route.txt")"
fi
