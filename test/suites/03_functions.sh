#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/03_functions.sh
# Updated at : 2026-10-22
# Creator    : palarchsys
# =============================================================================

hft_section "fonctions conservées"
MONO="$(cd -- "${HFT_ROOT}/.." && pwd)"

hft_require_function() {
    local name="$1"
    local where="$2"
    if grep -RInE "^${name}[[:space:]]*\\(\\)" ${where} >/dev/null 2>&1; then
        hft_pass "fn:${name}" "présente"
    else
        hft_fail "fn:${name}" "absente de ${where}"
    fi
}

for name in hf_set_color_blue hf_require_root hf_set_step_visible hf_log_error hf_run_silent hf_run_optional hf_run_silent_apt hf_run_step \
    hf_add_line hf_copy_backup hf_ensure_directory hf_check_user hf_init_install_log \
    hf_collect_install_log hf_publish_repo_logs hf_check_debug_log hf_install_exit \
    hf_copy_installed_logs; do
    hft_require_function "${name}" "${MONO}/core"
done
for name in hf_get_current_user hf_get_operating_system hf_os_version_at_least hfu_check_desktop_account hf_write_account_table \
    hf_record_account_snapshot hfu_strip_virt_groups hf_check_account_drift hf_get_ssh_port \
    hf_check_virtual_machine hf_check_app hf_check_password_unchanged hf_check_ubuntu_pro \
    hfu_collect_product_logs; do
    hft_require_function "${name}" "${HFT_ROOT}/core/lib.sh"
done
for name in hf_check_email hf_check_port hf_check_smtp hf_check_absolute_path hf_check_app_password; do
    hft_require_function "${name}" "${MONO}/core/config-validators.sh"
done
hft_require_function hfu_check_pro_token "${HFT_ROOT}/scripts/config-check.sh"
hft_require_function hf_check_localhost_port "${MONO}/server/core/lib.sh"

hft_section "version ubuntu"
if bash -c "
set -euo pipefail
HF_INSTALL_DIRECTORY='${HFT_ROOT}'
source \"\${HF_INSTALL_DIRECTORY}/core/lib.sh\"
hf_os_version_at_least 26.04 26.04
hf_os_version_at_least 26.10 26.04
hf_os_version_at_least 28.04 26.04
hf_os_version_at_least 26.04.1 26.04
if hf_os_version_at_least 24.04 26.04; then exit 1; fi
if hf_os_version_at_least 26.03 26.04; then exit 1; fi
if hf_os_version_at_least foo 26.04; then exit 1; fi
"; then
    hft_pass "fn.os.floor" "26.04, 26.10 et 28.04 passent, 24.04 échoue"
else
    hft_fail "fn.os.floor" "comparaison de version"
fi
if grep -q '!= "26.04"' "${HFT_ROOT}/core/lib.sh"; then
    hft_fail "fn.os.strict" "la version est comparée par égalité stricte"
else
    hft_pass "fn.os.strict" "la version est comparée au plancher"
fi

hft_section "journaux dans logs/"
if grep -q 'trap hf_install_exit EXIT' "${HFT_ROOT}/scripts/run.sh" \
   && grep -q 'HF_LOG_DIR="${root}/logs/${name}"' "${MONO}/core/log.sh" \
   && grep -F -q '[[ "${code}" -ne 0 ]]' "${MONO}/core/log.sh"; then
    hft_pass "logs.wire" "le poste écrit dans logs/ et copie les logiciels seulement en échec"
else
    hft_fail "logs.wire" "journaux du poste encore hors de logs/, ou copie même en succès"
fi
hft_require_function hf_render_mail "${MONO}/core/mail.sh"
hft_require_function hf_install_mail_templates "${MONO}/core/mail.sh"

hft_section "mode test du poste"
if grep -q '^HF_MODE_TEST=1$' "${HFT_ROOT}/config/global.conf" \
   && ! grep -q '^HFS_SERVER_TYPE=' "${HFT_ROOT}/config/global.conf" \
   && grep -q '^HF_MODE_TEST=${HF_MODE_TEST}$' "${HFT_ROOT}/scripts/config-check.sh" \
   && ! grep -q 'HFS_SERVER_TYPE' "${HFT_ROOT}/scripts/config-check.sh" \
   && grep -q 'hfu_prompt HF_MODE_TEST' "${HFT_ROOT}/scripts/configure.sh" \
   && grep -q 'bool01' "${HFT_ROOT}/scripts/configure.sh" \
   && ! grep -q 'HFS_SERVER_TYPE' "${HFT_ROOT}/scripts/run.sh" \
   && ! grep -RIn --include='*.sh' 'HFS_SERVER_TYPE' \
        "${HFT_ROOT}/system" "${HFT_ROOT}/service" "${HFT_ROOT}/verify" | grep -q . \
   && grep -q 'HF_MODE_TEST:-0' "${MONO}/core/log.sh"; then
    hft_pass "user.mode-test" "HF_MODE_TEST=1, HFS_SERVER_TYPE absent du poste"
else
    hft_fail "user.mode-test" "HF_MODE_TEST ou HFS_SERVER_TYPE mal placé"
fi

stage="$(mktemp -d)"
if bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$1"
    hfu_set_config_default
    hfu_write_global_config "$2/global.conf"
    grep -q "^HF_MODE_TEST=1$" "$2/global.conf"
    ! grep -q "^HFS_SERVER_TYPE=" "$2/global.conf"
' bash "${HFT_ROOT}/scripts/config-check.sh" "${stage}"; then
    hft_pass "user.mode-test.write" "le fichier réécrit porte HF_MODE_TEST=1, sans HFS_SERVER_TYPE"
else
    hft_fail "user.mode-test.write" "la réécriture omet HF_MODE_TEST ou garde HFS_SERVER_TYPE"
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
out="$(HF_PRODUCT_ROOT="${HFT_ROOT}" bash -c '
    set -euo pipefail
    unset HFS_SERVER_TYPE || true
    # shellcheck disable=SC1090
    source "$1"
    hf_run_step "$2" "one.sh"
    hf_run_step "$2" MATRIX "two.sh"
' bash "${HFT_ROOT}/core/lib.sh" "${tree}" 2>/dev/null)" || out=""
if [[ "${out}" == "A:${tree}:"$'\n'"B:${tree}:MATRIX" ]]; then
    hft_pass "user.mode-test.steps" "le poste lance l'étape sans profil, le serveur garde le sien"
else
    hft_fail "user.mode-test.steps" "arguments reçus : ${out}"
fi
rm -rf "${tree}"

log_work="$(mktemp -d)"
if HF_PRODUCT_ROOT="${HFT_ROOT}" bash -c '
    set -euo pipefail
    unset HFS_SERVER_TYPE || true
    # shellcheck disable=SC1090
    source "$1"
    HF_INSTALL_DIRECTORY="$2"
    export HF_INSTALL_DIRECTORY
    HFU_PROJECT_SLUG=high-fortress-user
    HF_PROJECT_NAME=HF
    hf_init_install_log
    [[ "${HF_LOG_DIR}" == "${HF_INSTALL_DIRECTORY}/logs/install-"*"-user" ]]
' bash "${HFT_ROOT}/core/lib.sh" "${log_work}"; then
    hft_pass "user.mode-test.logname" "journal nommé install-*-user"
else
    hft_fail "user.mode-test.logname" "le journal du poste ne se termine pas par -user"
fi
rm -rf "${log_work}"

if timeout 3 bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$1"
    unset HF_INSTALL_DIRECTORY || true
    # shellcheck disable=SC1090
    source "$2"
    [[ "${HF_MODE_TEST}" == "1" ]]
    [[ -z "${HFS_SERVER_TYPE:-}" ]]
    work="$(mktemp -d)"
    trap "rm -rf -- \"${work}\"" EXIT
    mkdir -p "${work}/inst/scripts" "${work}/inst/config" "${work}/base"
    printf x > "${work}/inst/hf"
    printf x > "${work}/inst/scripts/run.sh"
    printf C > "${work}/inst/config/global.conf"
    inst="$(cd -- "${work}/inst" && pwd -P)"
    base="$(cd -- "${work}/base" && pwd -P)"
    out="$(HF_INSTALL_DIRECTORY="${inst}" HF_CONFIG_BASE_DIRECTORY="${base}" hf_offer_remove_installer 2>&1)"
    [[ "${out}" != *[Ss]upprimer* ]]
    [[ -f "${inst}/hf" && -f "${inst}/config/global.conf" ]]
' bash "${MONO}/core/log.sh" "${HFT_ROOT}/config/global.conf"; then
    hft_pass "user.mode-test.skip" "HF_MODE_TEST=1 termine sans question"
else
    hft_fail "user.mode-test.skip" "la question de suppression part encore"
fi
