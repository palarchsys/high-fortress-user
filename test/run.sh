#!/usr/bin/env bash
# Banc statique du poste. Pas de root, pas d'installation.
# Code 0 si aucun FAIL.
set -euo pipefail

USER_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MONO="$(cd -- "${USER_ROOT}/.." && pwd)"
STAMP="$(date '+%Y%m%d-%H%M%S')"
OUT="${USER_ROOT}/test/output/${STAMP}"
mkdir -p "${OUT}"
PASS=0
FAIL=0
: > "${OUT}/results.tsv"

record() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "${OUT}/results.tsv"
    printf '%s  %s — %s\n' "$1" "$2" "$3"
}

ok() { PASS=$((PASS + 1)); record PASS "$1" "$2"; }
ko() { FAIL=$((FAIL + 1)); record FAIL "$1" "$2"; }

section() { printf '\n── %s ──\n' "$1"; }

section "bash -n"
while IFS= read -r file; do
    rel="${file#"${MONO}/"}"
    if bash -n "${file}" 2>"${OUT}/bash-n.err"; then
        ok "syntax:${rel}" "bash -n"
    else
        ko "syntax:${rel}" "$(tr '\n' ' ' < "${OUT}/bash-n.err")"
    fi
done < <(find "${USER_ROOT}" "${MONO}/core" "${MONO}/agents" "${MONO}/scripts" \
    -name '*.sh' -type f \
    -not -path '*/test/output/*' \
    -not -path '*/node_modules/*' | sort)

section "étapes de run.sh"
while IFS= read -r step; do
    [[ -z "${step}" ]] && continue
    if [[ -f "${USER_ROOT}/${step}" ]]; then
        ok "graph:${step}" "présent"
    else
        ko "graph:${step}" "introuvable"
    fi
done < <(grep -oE '"(system|service|verify)/[^"]+\.sh"' "${USER_ROOT}/run.sh" | tr -d '"' | sort -u)

section "fonctions conservées"
need_fn() {
    local name="$1"
    local where="$2"
    if grep -RInE "^${name}[[:space:]]*\\(\\)" ${where} >/dev/null 2>&1; then
        ok "fn:${name}" "présente"
    else
        ko "fn:${name}" "absente de ${where}"
    fi
}
for name in blue require_root step_on error run_silent try_silent run_silent_apt run_steps \
    add_line_if_missing backup_file_once ensure_dir user_exists init_install_log \
    collect_install_logs hf_publish_repo_logs hf_debug_logs_enabled; do
    need_fn "${name}" "${MONO}/core"
done
for name in detect_current_user detect_os hfu_is_desktop_account write_human_account_table \
    snapshot_human_accounts hfu_strip_virt_groups human_accounts_drift detect_ssh_port \
    virt_present app_present assert_no_password_mutation ubuntu_pro_attached \
    hfu_collect_product_logs; do
    need_fn "${name}" "${USER_ROOT}/lib.sh"
done
for name in hfu_is_email hfu_is_port hfu_is_smtp hfu_is_abs_path hfu_is_secret hf_is_app_password; do
    need_fn "${name}" "${MONO}/core/config-validators.sh"
done
need_fn hfu_is_pro_token "${USER_ROOT}/config-check.sh"
need_fn assert_localhost_port_free "${MONO}/server/lib.sh"

section "interdits poste"
active_hits() {
    local pattern="$1"
    grep -RInE --include='*.sh' --include='*.conf' --include='*.service' "${pattern}" "${USER_ROOT}" \
        | grep -vE ':[0-9]+:[[:space:]]*#' || true
}
forbid() {
    local id="$1"
    local pattern="$2"
    local hits
    hits="$(active_hits "${pattern}")"
    if [[ -n "${hits}" ]]; then
        ko "${id}" "$(printf '%s' "${hits}" | tr '\n' ' ' | head -c 500)"
    else
        ok "${id}" "aucune ligne active"
    fi
}
forbid "forbid.password-no" '^[[:space:]]*PasswordAuthentication[[:space:]]+no([[:space:]]|$)'
forbid "forbid.allowusers" '^[[:space:]]*AllowUsers[[:space:]]'
forbid "forbid.ufw-out" 'ufw[[:space:]]+default[[:space:]]+deny[[:space:]]+outgoing'
forbid "forbid.ufw-reset" 'ufw[[:space:]]+--force[[:space:]]+reset'
forbid "forbid.ipv6" 'disable_ipv6[[:space:]]*='
forbid "forbid.usb" '(^|[[:space:]])(blacklist|install)[[:space:]]+usb-storage'
tmp_hits="$(active_hits '/tmp[^#]*noexec|noexec[^#]*/tmp' | grep -v '/verify/' | grep -v 'est noexec' || true)"
if [[ -n "${tmp_hits}" ]]; then
    ko "forbid.tmp-noexec" "$(printf '%s' "${tmp_hits}" | tr '\n' ' ' | head -c 500)"
else
    ok "forbid.tmp-noexec" "aucune ligne active"
fi

chpasswd_hits="$(grep -RIn --include='*.sh' --exclude-dir=test 'chpasswd' "${USER_ROOT}" \
    | grep -vE ':[0-9]+:[[:space:]]*#' \
    | grep -v '\*chpasswd\*' \
    | grep -v 'aucun chpasswd' \
    | grep -v 'jamais chpasswd' || true)"
if [[ -n "${chpasswd_hits}" ]]; then
    ko "forbid.chpasswd" "$(printf '%s' "${chpasswd_hits}" | tr '\n' ' ' | head -c 500)"
else
    ok "forbid.chpasswd" "pas d'appel chpasswd"
fi

if grep -RInE --include='*.sh' 'chmod[[:space:]]+700[[:space:]]+.*(gcc|g\+\+|/usr/bin/cc)' "${USER_ROOT}" | grep -vE ':[0-9]+:[[:space:]]*#' | grep -q .; then
    ko "forbid.compiler-700" "chmod 700 sur un compilateur"
else
    ok "forbid.compiler-700" "compilateurs non verrouillés"
fi

if [[ -f "${MONO}/server/service/ssh/00-high-fortress-user.conf" ]]; then
    ko "forbid.dropin-on-server" "le drop-in poste est dans server/service/ssh"
else
    ok "forbid.dropin-on-server" "drop-in poste absent du serveur"
fi
if grep -q '^PasswordAuthentication yes$' "${MONO}/server/service/ssh/sshd_config.conf" 2>/dev/null; then
    ko "forbid.server-ssh-password" "le sshd serveur accepte le mot de passe"
else
    ok "forbid.server-ssh-password" "sshd serveur sans mot de passe"
fi

section "secrets hors git"
for repo in server user web; do
    if git -C "${MONO}/${repo}" ls-files | grep -E '(^|/)secrets\.conf$|\.env$|human\.tsv$' >/dev/null; then
        ko "secrets:${repo}" "fichier sensible indexé"
    else
        ok "secrets:${repo}" "index propre"
    fi
done

section "contrat SQL"
sql_web="${MONO}/web/backend/app/db/sql/001_tables.sql"
sql_server="${MONO}/server/docker/web/sql/001_tables.sql"
if [[ ! -f "${sql_web}" || ! -f "${sql_server}" ]]; then
    ko "sql.present" "un des deux SQL est absent"
elif cmp -s "${sql_web}" "${sql_server}"; then
    ok "sql.match" "001_tables.sql identique"
else
    ko "sql.match" "diffère — recopier avec : cp web/backend/app/db/sql/001_tables.sql server/docker/web/sql/001_tables.sql"
fi

section "routeur"
if bash "${MONO}/agents/route.sh" --check > "${OUT}/route.txt"; then
    ok "route.check" "fichiers cités présents"
else
    ko "route.check" "$(tr '\n' ' ' < "${OUT}/route.txt")"
fi

{
    echo "# Rapport user/test"
    echo ""
    echo "PASS=${PASS} FAIL=${FAIL}"
    echo ""
    echo "Détail : results.tsv"
} > "${OUT}/summary.md"

printf '\nRésultat : %s PASS, %s FAIL\n' "${PASS}" "${FAIL}"
printf 'Rapport : %s/summary.md\n' "${OUT}"
if [[ "${FAIL}" -ne 0 ]]; then
    exit 1
fi
