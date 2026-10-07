#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/02_file_graph.sh
# Updated at : 2026-10-07
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

hf_section "debsums et mirrors.dat"
rk="${HF_ROOT}/service/cron/watchdogs/rkhunter.sh"
check_line="$(grep -n 'record-mirrors.sh" check' "${rk}" | head -1 | cut -d: -f1)"
update_line="$(grep -n 'rkhunter --update' "${rk}" | head -1 | cut -d: -f1)"
save_line="$(grep -n 'record-mirrors.sh" save' "${rk}" | head -1 | cut -d: -f1)"
if [[ -x "${HF_ROOT}/service/cron/watchdogs/record-mirrors.sh" ]] \
   && [[ -n "${check_line}" && -n "${update_line}" && -n "${save_line}" ]] \
   && [[ "${check_line}" -lt "${update_line}" && "${update_line}" -lt "${save_line}" ]] \
   && grep -q 'rkhunter-mirrors.sha256' "${HF_ROOT}/service/cron/watchdogs/debsums.sh" \
   && grep -q 'record-mirrors.sh" save' "${HF_ROOT}/service/rkhunter/init-db.sh" \
   && [[ ! -e "${HF_ROOT}/service/cron/watchdogs/debsums.ignore" ]]; then
    hf_pass "graph.debsums.mirrors" "empreinte après --update, le fichier n'est pas ignoré"
else
    hf_fail "graph.debsums.mirrors" "mirrors.dat doit rester contrôlé hors de rkhunter --update"
fi

hf_section "clamav verrous de quarantaine"
evt="${HF_ROOT}/service/cron/watchdogs/clamav-event.sh"
if grep -q 'clamav-quarantine-lock' "${evt}" \
   && awk '
        /clamav-quarantine-lock/ { lock = NR }
        /log_alert/ { if (lock && !alert) alert = NR }
        END { exit !(lock && alert && alert > lock) }
      ' "${evt}"; then
    hf_pass "graph.clamav.locks" "un verrou de quarantaine sort avant le courrier"
else
    hf_fail "graph.clamav.locks" "les verrous .clamav-quarantine-lock.* ne doivent pas envoyer de courrier"
fi

hf_section "readme"
readme="${HF_ROOT}/README.md"
en="${HF_ROOT}/docs/en/README.md"
fr="${HF_ROOT}/docs/fr/README.md"
pages_ok=1
for lang in en fr de es; do
    for page in README.md configuration.md surveillance.md architecture.md files.md logs.md; do
        if [[ ! -f "${HF_ROOT}/docs/${lang}/${page}" ]]; then
            pages_ok=0
        elif [[ "${page}" != "README.md" ]] && ! head -1 "${HF_ROOT}/docs/${lang}/${page}" | grep -q 'README.md'; then
            pages_ok=0
        fi
    done
done
for old in configuration.md surveillance.md architecture.md files.md logs.md; do
    [[ -f "${HF_ROOT}/${old}" ]] && pages_ok=0
done
grep -qF '## Documentation' "${readme}" || pages_ok=0
grep -qF 'Click a flag to open all the information.' "${readme}" || pages_ok=0
grep -qF 'width="100%"' "${readme}" || pages_ok=0
grep -qF 'Do not copy it into a message, a ticket, or a repository.' "${readme}" && pages_ok=0
for flag in en fr de es; do
    [[ -f "${HF_ROOT}/docs/flags/${flag}.svg" ]] || pages_ok=0
    grep -qF "docs/flags/${flag}.svg" "${readme}" || pages_ok=0
done
warn='`secrets.conf` stays on the machine. Do not copy it into a message, a ticket, or a repository.'
desc_lines=0
while IFS= read -r line; do
    line="${line//${warn}/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "${line}" ]] && continue
    desc_lines=$((desc_lines + 1))
    grep -qF "${line}" "${readme}" || pages_ok=0
done < <(awk '
    /^## Description$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "${en}")
[[ "${desc_lines}" -ge 2 ]] || pages_ok=0
if grep -qF '# High-Fortress User' "${readme}" \
   && grep -qF 'https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh' "${readme}" \
   && grep -qF 'ca-certificates curl git swaks tar' "${readme}" \
   && grep -qF 'docs/en/README.md' "${readme}" \
   && grep -qF 'docs/fr/README.md' "${readme}" \
   && grep -qF 'docs/de/README.md' "${readme}" \
   && grep -qF 'docs/es/README.md' "${readme}" \
   && ! grep -qF '## Avant de commencer' "${readme}" \
   && ! grep -R -qF 'disable_ipv6' "${HF_ROOT}/docs" \
   && ! grep -R -qF 'PasswordAuthentication no' "${HF_ROOT}/docs" \
   && grep -qF 'Ne le copiez pas dans un message, un ticket ou un dépôt.' "${fr}" \
   && grep -qF 'LYNIS_MIN_SCORE' "${en}" \
   && grep -qF 'is 80' "${en}" \
   && awk '
        /^## Description$/ { h[++n] = NR }
        /^## Before you start$/ { h[++n] = NR }
        /^## Installation$/ { h[++n] = NR }
        /^## What configure.sh does$/ { h[++n] = NR }
        /^## Installed software and services$/ { h[++n] = NR }
        /^## What the machine does after installation$/ { h[++n] = NR }
        /^## Alert emails$/ { h[++n] = NR }
        /^## Commands after installation$/ { h[++n] = NR }
        /^## Detailed pages$/ { h[++n] = NR }
        END {
            if (n != 9) exit 1
            for (i = 2; i <= n; i++) if (h[i] <= h[i-1]) exit 1
        }
      ' "${en}" \
   && awk '
        /^## Description$/ { h[++n] = NR }
        /^## Avant de commencer$/ { h[++n] = NR }
        /^## Installation$/ { h[++n] = NR }
        /^## Action de configure.sh$/ { h[++n] = NR }
        /^## Logiciels et services installés$/ { h[++n] = NR }
        /^## Ce que la machine fait après l'"'"'installation$/ { h[++n] = NR }
        /^## E-mails d'"'"'alerte$/ { h[++n] = NR }
        /^## Commandes après l'"'"'installation$/ { h[++n] = NR }
        /^## Fichiers détaillés$/ { h[++n] = NR }
        END {
            if (n != 9) exit 1
            for (i = 2; i <= n; i++) if (h[i] <= h[i-1]) exit 1
        }
      ' "${fr}" \
   && [[ "${pages_ok}" -eq 1 ]]; then
    hf_pass "graph.readme" "squelette du README et pages liées"
else
    hf_fail "graph.readme" "le README du poste doit suivre agents/laws/readme.md"
fi
