#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/06_sql_contract.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

hf_section "contrat SQL"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"
sql_web="${MONO}/web/backend/app/db/sql/001_tables.sql"
sql_server="${MONO}/server/docker/web/sql/001_tables.sql"
if [[ ! -f "${sql_web}" || ! -f "${sql_server}" ]]; then
    hf_fail "sql.present" "un des deux SQL est absent"
elif cmp -s "${sql_web}" "${sql_server}"; then
    hf_pass "sql.match" "001_tables.sql identique"
else
    hf_fail "sql.match" "diffère — recopier avec : cp web/backend/app/db/sql/001_tables.sql server/docker/web/sql/001_tables.sql"
fi
