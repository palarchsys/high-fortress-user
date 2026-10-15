#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/07_router.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

hft_section "routeur"
root=""
here="${HFT_ROOT}"
while [[ "${here}" != "/" ]]; do
    if [[ -f "${here}/agents/route.sh" ]]; then
        root="${here}"
        break
    fi
    here="$(dirname -- "${here}")"
done

if [[ -z "${root}" ]]; then
    hft_fail "route.check" "agents/route.sh introuvable au-dessus de ${HFT_ROOT}"
elif bash "${root}/agents/route.sh" --check > "${HF_ARTIFACTS}/route.txt"; then
    hft_pass "route.check" "fichiers cités présents"
else
    hft_fail "route.check" "$(tr '\n' ' ' < "${HF_ARTIFACTS}/route.txt")"
fi
