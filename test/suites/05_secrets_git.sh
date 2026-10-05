#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/05_secrets_git.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

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
