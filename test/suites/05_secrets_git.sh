#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/05_secrets_git.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

hft_section "secrets hors git"
MONO="$(cd -- "${HFT_ROOT}/.." && pwd)"
for repo in server user web; do
    if git -C "${MONO}/${repo}" ls-files | grep -E '(^|/)secrets\.conf$|\.env$|human\.tsv$' >/dev/null; then
        hft_fail "secrets:${repo}" "fichier sensible indexé"
    else
        hft_pass "secrets:${repo}" "index propre"
    fi
    if git -C "${MONO}/${repo}" ls-files | grep -E '(^|/)AGENTS\.md$' >/dev/null; then
        hft_fail "agents:${repo}" "AGENTS.md indexé"
    else
        hft_pass "agents:${repo}" "aucun AGENTS.md"
    fi
done
