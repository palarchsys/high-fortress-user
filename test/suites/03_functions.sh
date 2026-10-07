#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/03_functions.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

hf_section "fonctions conservées"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"

need_fn() {
    local name="$1"
    local where="$2"
    if grep -RInE "^${name}[[:space:]]*\\(\\)" ${where} >/dev/null 2>&1; then
        hf_pass "fn:${name}" "présente"
    else
        hf_fail "fn:${name}" "absente de ${where}"
    fi
}

for name in blue require_root step_on error run_silent try_silent run_silent_apt run_steps \
    add_line_if_missing backup_file_once ensure_dir user_exists init_install_log \
    collect_install_logs hf_publish_repo_logs hf_debug_logs_enabled hf_install_exit \
    hf_copy_installed_logs; do
    need_fn "${name}" "${MONO}/core"
done
for name in detect_current_user detect_os hfu_is_desktop_account write_human_account_table \
    snapshot_human_accounts hfu_strip_virt_groups human_accounts_drift detect_ssh_port \
    virt_present app_present assert_no_password_mutation ubuntu_pro_attached \
    hfu_collect_product_logs; do
    need_fn "${name}" "${HF_ROOT}/core/lib.sh"
done
for name in hfu_is_email hfu_is_port hfu_is_smtp hfu_is_abs_path hfu_is_secret hf_is_app_password; do
    need_fn "${name}" "${MONO}/core/config-validators.sh"
done
need_fn hfu_is_pro_token "${HF_ROOT}/scripts/config-check.sh"
need_fn assert_localhost_port_free "${MONO}/server/core/lib.sh"

hf_section "journaux dans logs/"
if grep -q 'trap hf_install_exit EXIT' "${HF_ROOT}/scripts/run.sh" \
   && grep -q 'HF_LOG_DIR="${root}/logs/${name}"' "${MONO}/core/log.sh" \
   && grep -F -q '[[ "${code}" -ne 0 ]]' "${MONO}/core/log.sh"; then
    hf_pass "logs.wire" "le poste écrit dans logs/ et copie les logiciels seulement en échec"
else
    hf_fail "logs.wire" "journaux du poste encore hors de logs/, ou copie même en succès"
fi
need_fn hf_render_mail "${MONO}/core/mail.sh"
need_fn hf_install_mail_templates "${MONO}/core/mail.sh"

hf_section "mode test du poste"
if grep -q '^MODE_TEST=1$' "${HF_ROOT}/config/global.conf" \
   && ! grep -q '^SERVER_TYPE=' "${HF_ROOT}/config/global.conf" \
   && grep -q '^MODE_TEST=${MODE_TEST}$' "${HF_ROOT}/scripts/config-check.sh" \
   && ! grep -q 'SERVER_TYPE' "${HF_ROOT}/scripts/config-check.sh" \
   && grep -q 'hfu_prompt MODE_TEST' "${HF_ROOT}/scripts/configure.sh" \
   && grep -q 'bool01' "${HF_ROOT}/scripts/configure.sh" \
   && ! grep -q 'SERVER_TYPE' "${HF_ROOT}/scripts/run.sh" \
   && ! grep -RIn --include='*.sh' 'SERVER_TYPE' \
        "${HF_ROOT}/system" "${HF_ROOT}/service" "${HF_ROOT}/verify" | grep -q . \
   && grep -q 'MODE_TEST:-0' "${MONO}/core/log.sh"; then
    hf_pass "user.mode-test" "MODE_TEST=1, SERVER_TYPE absent du poste"
else
    hf_fail "user.mode-test" "MODE_TEST ou SERVER_TYPE mal placé"
fi

stage="$(mktemp -d)"
if bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$1"
    hfu_config_set_builtin_defaults
    hfu_write_global_conf "$2/global.conf"
    grep -q "^MODE_TEST=1$" "$2/global.conf"
    ! grep -q "^SERVER_TYPE=" "$2/global.conf"
' bash "${HF_ROOT}/scripts/config-check.sh" "${stage}"; then
    hf_pass "user.mode-test.write" "le fichier réécrit porte MODE_TEST=1, sans SERVER_TYPE"
else
    hf_fail "user.mode-test.write" "la réécriture omet MODE_TEST ou garde SERVER_TYPE"
fi
rm -rf "${stage}"

tree="$(mktemp -d)"
cat > "${tree}/one.sh" << 'EOF'
#!/usr/bin/env bash
printf 'A:%s:%s\n' "$1" "${2-}"
EOF
cat > "${tree}/two.sh" << 'EOF'
#!/usr/bin/env bash
printf 'B:%s:%s\n' "$1" "${2-}"
EOF
out="$(HF_PRODUCT_ROOT="${HF_ROOT}" bash -c '
    set -euo pipefail
    unset SERVER_TYPE || true
    # shellcheck disable=SC1090
    source "$1"
    run_steps "$2" "one.sh"
    run_steps "$2" MATRIX "two.sh"
' bash "${HF_ROOT}/core/lib.sh" "${tree}" 2>/dev/null)" || out=""
if [[ "${out}" == "A:${tree}:"$'\n'"B:${tree}:MATRIX" ]]; then
    hf_pass "user.mode-test.steps" "le poste lance l'étape sans profil, le serveur garde le sien"
else
    hf_fail "user.mode-test.steps" "arguments reçus : ${out}"
fi
rm -rf "${tree}"

log_work="$(mktemp -d)"
if HF_PRODUCT_ROOT="${HF_ROOT}" bash -c '
    set -euo pipefail
    unset SERVER_TYPE || true
    # shellcheck disable=SC1090
    source "$1"
    DIR_INSTALL_PATH="$2"
    export DIR_INSTALL_PATH
    PROJECT_SLUG=high-fortress-user
    PROJECT_NAME=HF
    init_install_log
    [[ "${HF_LOG_DIR}" == "${DIR_INSTALL_PATH}/logs/install-"*"-user" ]]
' bash "${HF_ROOT}/core/lib.sh" "${log_work}"; then
    hf_pass "user.mode-test.logname" "journal nommé install-*-user"
else
    hf_fail "user.mode-test.logname" "le journal du poste ne se termine pas par -user"
fi
rm -rf "${log_work}"

if timeout 3 bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$1"
    unset DIR_INSTALL_PATH || true
    # shellcheck disable=SC1090
    source "$2"
    [[ "${MODE_TEST}" == "1" ]]
    [[ -z "${SERVER_TYPE:-}" ]]
    work="$(mktemp -d)"
    trap "rm -rf -- \"${work}\"" EXIT
    mkdir -p "${work}/inst/scripts" "${work}/inst/config" "${work}/base"
    printf x > "${work}/inst/hf"
    printf x > "${work}/inst/scripts/run.sh"
    printf C > "${work}/inst/config/global.conf"
    inst="$(cd -- "${work}/inst" && pwd -P)"
    base="$(cd -- "${work}/base" && pwd -P)"
    out="$(DIR_INSTALL_PATH="${inst}" CONFIG_BASE_DIR="${base}" hf_offer_remove_installer 2>&1)"
    [[ "${out}" != *[Ss]upprimer* ]]
    [[ -f "${inst}/hf" && -f "${inst}/config/global.conf" ]]
' bash "${MONO}/core/log.sh" "${HF_ROOT}/config/global.conf"; then
    hf_pass "user.mode-test.skip" "MODE_TEST=1 termine sans question"
else
    hf_fail "user.mode-test.skip" "la question de suppression part encore"
fi
