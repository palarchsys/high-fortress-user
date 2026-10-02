#!/usr/bin/env bash

# Suite 05 — secrets et AGENTS.md hors des dépôts produits.

hf_section "secrets hors git"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"
for repo in server user web; do
    if git -C "${MONO}/${repo}" ls-files | grep -E '(^|/)secrets\.conf$|\.env$|human\.tsv$' >/dev/null; then
        hf_fail "secrets:${repo}" "fichier sensible indexé"
    else
        hf_pass "secrets:${repo}" "index propre"
    fi
    if git -C "${MONO}/${repo}" ls-files | grep -E '(^|/)AGENTS\.md$' >/dev/null; then
        hf_fail "agents:${repo}" "AGENTS.md indexé"
    else
        hf_pass "agents:${repo}" "aucun AGENTS.md"
    fi
done
