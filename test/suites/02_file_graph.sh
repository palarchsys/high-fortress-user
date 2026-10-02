#!/usr/bin/env bash

# Suite 02 — étapes citées par scripts/run.sh.

hf_section "étapes de run.sh"
while IFS= read -r step; do
    [[ -z "${step}" ]] && continue
    if [[ -f "${HF_ROOT}/${step}" ]]; then
        hf_pass "graph:${step}" "présent"
    else
        hf_fail "graph:${step}" "introuvable"
    fi
done < <(grep -oE '"(system|service|verify)/[^"]+\.sh"' "${HF_ROOT}/scripts/run.sh" | tr -d '"' | sort -u)

hf_section "modèle de mail dans template/"
if [[ -f "${HF_ROOT}/template/mail.html" ]]; then
    hf_pass "graph.template:mail.html" "présent : template/mail.html"
else
    hf_fail "graph.template:mail.html" "fichier introuvable : template/mail.html"
fi
if [[ -e "${HF_ROOT}/service/cron/watchdogs/mail.html" ]]; then
    hf_fail "graph.template:not-in-watchdogs" "mail.html est encore dans service/cron/watchdogs"
else
    hf_pass "graph.template:not-in-watchdogs" "le modèle n'est pas enfoui dans les watchdogs"
fi
