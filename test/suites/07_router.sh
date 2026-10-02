#!/usr/bin/env bash

# Suite 07 — chaque fichier cité par le routeur existe.

hf_section "routeur"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"
if bash "${MONO}/agents/route.sh" --check > "${HF_ARTIFACTS}/route.txt"; then
    hf_pass "route.check" "fichiers cités présents"
else
    hf_fail "route.check" "$(tr '\n' ' ' < "${HF_ARTIFACTS}/route.txt")"
fi
