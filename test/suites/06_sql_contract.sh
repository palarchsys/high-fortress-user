#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/06_sql_contract.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

hft_section "contrat SQL"
root=""
here="${HFT_ROOT}"
while [[ "${here}" != "/" ]]; do
    if [[ -f "${here}/agents/laws/server.md" ]]; then
        root="${here}"
        break
    fi
    here="$(dirname -- "${here}")"
done

sql_server=""
sql_web=""
law=""
if [[ -n "${root}" ]]; then
    sql_server="${root}/src/server/docker/web/sql/001_tables.sql"
    sql_web="${root}/src/web/backend/app/db/sql/001_tables.sql"
    law="${root}/agents/laws/server.md"
fi

if [[ -z "${root}" ]]; then
    hft_fail "sql.contract" "agents/laws/server.md introuvable au-dessus du produit"
elif [[ -f "${sql_server}" || -f "${sql_web}" ]]; then
    hft_fail "sql.contract" "001_tables.sql est revenu dans server ou src/web"
elif ! grep -qF 'high-fortress-web' "${law}" \
    || ! grep -qF 'ne crée pas les tables' "${law}"; then
    hft_fail "sql.contract" "la loi serveur doit laisser les tables à high-fortress-web"
else
    hft_pass "sql.contract" "tables générées par high-fortress-web, aucune copie dans server ni src/web"
fi
