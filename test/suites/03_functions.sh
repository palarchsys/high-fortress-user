#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/03_functions.sh
# Updated at : 2026-10-27
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
for name in hf_get_current_user hf_get_operating_system hf_check_ubuntu_base hfu_check_desktop_account hf_write_account_table \
    hf_record_account_snapshot hfu_strip_virt_groups hf_check_account_drift hf_read_sshd_value hf_get_sshd_value hf_get_ssh_port \
    hf_check_virtual_machine hf_check_app hf_check_password_unchanged hf_check_ubuntu_pro \
    hfu_collect_product_logs; do
    hft_require_function "${name}" "${HFT_ROOT}/core/lib.sh"
done
for name in hf_check_email hf_check_port hf_check_smtp hf_check_absolute_path hf_check_drive_remote hf_check_drive_path hf_check_drive_probe hf_check_app_password; do
    hft_require_function "${name}" "${MONO}/core/config-validators.sh"
done
hft_require_function hfu_check_pro_token "${HFT_ROOT}/scripts/config-check.sh"
hft_require_function hf_check_localhost_port "${MONO}/server/core/lib.sh"

hft_section "base ubuntu"
if bash -s -- "${HFT_ROOT}" << 'OSBASE'
set -euo pipefail
root="$1"
HF_INSTALL_DIRECTORY="${root}"
# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'source /etc/os-release' "${HF_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'dpkg --compare-versions' "${HF_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'ge "26.04"' "${HF_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'hf_check_ubuntu_lts' "${HF_INSTALL_DIRECTORY}/core/lib.sh"
grep -qF '!= "ubuntu"' "${HF_INSTALL_DIRECTORY}/core/lib.sh"
if grep -q 'anduinos' "${HF_INSTALL_DIRECTORY}/core/lib.sh"; then
    exit 1
fi

pass_os() {
    local ID="$1"
    local ID_LIKE="$2"
    local UBUNTU_CODENAME="$3"
    local PRETTY_NAME="$4"
    local VERSION_ID="${5:-}"
    local expect_version="$6"
    local expect_code="$7"
    unset UBUNTU_BASE_VERSION UBUNTU_BASE_CODENAME
    hf_check_ubuntu_base
    [[ "${UBUNTU_BASE_VERSION}" == "${expect_version}" ]]
    [[ "${UBUNTU_BASE_CODENAME}" == "${expect_code}" ]]
}

fail_os() {
    local needle="$1"
    local id="$2"
    local like="$3"
    local code="$4"
    local pretty="$5"
    local version="${6:-}"
    local out rc
    set +e
    out=$(
        ID="${id}" ID_LIKE="${like}" UBUNTU_CODENAME="${code}" \
            PRETTY_NAME="${pretty}" VERSION_ID="${version}" \
            hf_check_ubuntu_base 2>&1
    )
    rc=$?
    set -e
    [[ "${rc}" -ne 0 ]]
    printf '%s\n' "${out}" | grep -q '26.04'
    printf '%s\n' "${out}" | grep -qF "${needle}"
}

pass_os ubuntu debian resolute "Ubuntu 26.04 LTS" "26.04" 26.04 resolute
pass_os ubuntu debian resolute "Ubuntu 26.04.1 LTS" "26.04.1" 26.04 resolute
pass_os ubuntu debian stonking "Ubuntu 26.10" "26.10" 26.10 stonking
pass_os ubuntu debian later "Ubuntu 28.04 LTS" "28.04" 28.04 later
pass_os ubuntu debian "" "Ubuntu 26.04" "26.04" 26.04 inconnu
fail_os AnduinOS anduinos "" resolute "AnduinOS" "1.4"
fail_os "Linux Mint" linuxmint "ubuntu debian" resolute "Linux Mint" "22"
fail_os "Custom derivative" custom "" resolute "Custom derivative" ""
fail_os 25.10 ubuntu debian questing "Ubuntu 25.10" "25.10"
fail_os 24.04 ubuntu debian noble "Ubuntu 24.04 LTS" "24.04"
fail_os 22.04 ubuntu debian jammy "Ubuntu 22.04 LTS" "22.04"
fail_os aucune ubuntu debian "" "Ubuntu" ""
fail_os Fedora fedora fedora "" "Fedora" "42"
OSBASE
then
    hft_pass "fn.os.base" "Ubuntu seul, 26.04 ou plus récent"
else
    hft_fail "fn.os.base" "la base Ubuntu n'accepte pas 26.04 ou plus récent"
fi
if grep -q '!= "26.04"' "${HFT_ROOT}/core/lib.sh"; then
    hft_fail "fn.os.strict" "la version est comparée par égalité stricte sur VERSION_ID"
else
    hft_pass "fn.os.strict" "la version est comparée au plancher 26.04"
fi

hft_section "sshd -T casse"
if bash -s -- "${HFT_ROOT}" << 'SSHCASE'
set -euo pipefail
root="$1"
HF_INSTALL_DIRECTORY="${root}"
# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
canon=$'Port 22\nPermitRootLogin no\nPasswordAuthentication yes\nAllowTcpForwarding no\n'
lower=$'port 2222\npermitrootlogin no\npasswordauthentication yes\n'
[[ "$(printf '%s\n' "${canon}" | hf_read_sshd_value permitrootlogin)" == "no" ]]
[[ "$(printf '%s\n' "${canon}" | hf_read_sshd_value PermitRootLogin)" == "no" ]]
[[ "$(printf '%s\n' "${canon}" | hf_read_sshd_value port)" == "22" ]]
[[ "$(printf '%s\n' "${lower}" | hf_read_sshd_value port)" == "2222" ]]
[[ "$(printf '%s\n' "${lower}" | hf_read_sshd_value permitrootlogin)" == "no" ]]
grep -q 'hf_get_sshd_value permitrootlogin' "${root}/service/ssh/configure.sh"
grep -q 'hf_get_sshd_value permitrootlogin' "${root}/../server/service/ssh/configure.sh"
grep -q 'hf_get_sshd_value allowtcpforwarding' "${root}/verify/workstation.sh"
grep -q 'tolower($1)=="permitrootlogin"' "${root}/service/cron/boot-check.sh"
if grep -RInE "awk '/\\^permitrootlogin " "${root}/service" "${root}/verify" "${root}/../server/service" >/dev/null 2>&1; then
    exit 1
fi
SSHCASE
then
    hft_pass "fn.sshd.case" "sshd -T lu en minuscules et en casse canonique"
else
    hft_fail "fn.sshd.case" "la lecture de sshd -T reste figée en minuscules"
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
    unset UBUNTU_BASE_VERSION || true
    OS_PRETTY="Ubuntu"
    OS_VERSION_ID="26.10"
    export OS_PRETTY OS_VERSION_ID
    hf_init_install_log
    [[ "${HF_LOG_DIR}" == "${HF_INSTALL_DIRECTORY}/logs/install-"*"-user" ]]
    grep -Fqx "os          : Ubuntu 26.10" "${HF_LOG_DIR}/meta.txt"
    grep -Fqx "os          : Ubuntu 26.10" "${HF_LOG_DIR}/install.log"
    OS_PRETTY="Ubuntu 26.10"
    export OS_PRETTY
    hf_init_install_log
    grep -Fqx "os          : Ubuntu 26.10" "${HF_LOG_DIR}/meta.txt"
    ! grep -Fqx "os          : Ubuntu 26.10 26.10" "${HF_LOG_DIR}/meta.txt"
' bash "${HFT_ROOT}/core/lib.sh" "${log_work}"; then
    hft_pass "user.mode-test.logname" "journal nommé install-*-user, version de distribution écrite une fois"
else
    hft_fail "user.mode-test.logname" "le journal du poste omet -user ou la version de distribution"
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
