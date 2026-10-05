#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/02_file_graph.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

hf_section "étapes de run.sh"
while IFS= read -r step; do
    [[ -z "${step}" ]] && continue
    if [[ -f "${HF_ROOT}/${step}" ]]; then
        hf_pass "graph:${step}" "présent"
    else
        hf_fail "graph:${step}" "introuvable"
    fi
done < <(grep -oE '"(system|service|verify)/[^"]+\.sh"' "${HF_ROOT}/scripts/run.sh" | tr -d '"' | sort -u)

hf_section "désinstallations avant system/install"
snap_line=$(grep -n 'system/snap-remove.sh' "${HF_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
purge_line=$(grep -n 'STEP_SYSTEM_PURGE\[@\]' "${HF_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
inst_line=$(grep -n 'STEP_SYSTEM_INSTALL\[@\]' "${HF_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
if [[ -n "${snap_line}" && -n "${purge_line}" && -n "${inst_line}" \
      && "${snap_line}" -lt "${purge_line}" && "${purge_line}" -lt "${inst_line}" ]] \
   && grep -q 'systemctl mask systemd-coredump.socket' "${HF_ROOT}/system/purge.sh" \
   && ! grep -q 'systemctl mask systemd-coredump.socket' "${HF_ROOT}/system/configure.sh" \
   && ! grep -qE 'purge -y cups|disable --now cups|mask apport' "${HF_ROOT}/system/purge.sh" \
   && awk '
        /upgrade -y --with-new-pkgs/ { up = NR }
        /HF_REAPPLY_LOCKS=1/ { if (up && !re) re = NR }
        END { exit !(up && re && re > up) }
      ' "${HF_ROOT}/scripts/run.sh"; then
    hf_pass "graph.order.purge-first" "snap (L${snap_line}), purge (L${purge_line}), install (L${inst_line})"
else
    hf_fail "graph.order.purge-first" "snap puis purge rc/coredump avant system/install ; CUPS reste"
fi

hf_section "purge rc avant les bases rkhunter et AIDE"
rc_line=$(grep -n 'HF_PURGE_RC_ONLY=1' "${HF_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
rk_line=$(grep -n 'service/rkhunter/init-db.sh' "${HF_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
aide_line=$(grep -n 'service/aide/init-db.sh' "${HF_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
if [[ -n "${rc_line}" && -n "${rk_line}" && -n "${aide_line}" \
      && "${rc_line}" -lt "${rk_line}" && "${rk_line}" -lt "${aide_line}" ]] \
   && ! grep -q 'dpkg --purge' "${HF_ROOT}/system/install.sh" \
   && ! grep -qF 'run_silent rkhunter --propupd' "${HF_ROOT}/service/rkhunter/configure.sh" \
   && grep -qF 'run_silent rkhunter --propupd' "${HF_ROOT}/service/rkhunter/init-db.sh"; then
    hf_pass "graph.order.purge-before-db" "purge rc (L${rc_line}) avant rkhunter (L${rk_line}) et AIDE (L${aide_line})"
else
    hf_fail "graph.order.purge-before-db" "la purge rc doit précéder --propupd et aide --init"
fi

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
