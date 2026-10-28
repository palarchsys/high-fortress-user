#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/03_functions.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

t_section "fonctions conservées"
MONO="$(cd -- "${T_ROOT}/.." && pwd)"

t_require_function() {
    local name="$1"
    local where="$2"
    if grep -RInE "^${name}[[:space:]]*\\(\\)" ${where} >/dev/null 2>&1; then
        t_pass "fn:${name}" "présente"
    else
        t_fail "fn:${name}" "absente de ${where}"
    fi
}

for name in g_set_color_blue g_require_root g_set_step_visible g_log_error g_run_silent g_run_optional g_run_silent_apt g_run_step \
    g_add_line g_copy_backup g_ensure_directory g_check_user g_init_install_log \
    g_collect_install_log g_publish_repo_logs g_check_debug_log g_install_exit \
    g_copy_installed_logs; do
    t_require_function "${name}" "${MONO}/core"
done
for name in g_get_current_user g_get_operating_system g_check_ubuntu_base w_check_desktop_account g_write_account_table \
    g_record_account_snapshot w_strip_virt_groups g_check_account_drift g_read_sshd_value g_get_sshd_value g_get_ssh_port \
    g_check_virtual_machine g_check_app g_check_password_unchanged g_check_ubuntu_pro \
    w_collect_product_logs; do
    t_require_function "${name}" "${T_ROOT}/core/lib.sh"
done
for name in g_check_email g_check_port g_check_smtp g_check_absolute_path g_check_drive_remote g_check_drive_path g_check_drive_probe g_check_app_password; do
    t_require_function "${name}" "${MONO}/core/config-validators.sh"
done
t_require_function w_check_pro_token "${T_ROOT}/scripts/config-check.sh"
t_require_function g_check_localhost_port "${MONO}/server/core/lib.sh"

t_section "base ubuntu"
if bash -s -- "${T_ROOT}" << 'OSBASE'
set -euo pipefail
root="$1"
G_INSTALL_DIRECTORY="${root}"
# shellcheck disable=SC1091
source "${G_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'source /etc/os-release' "${G_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'dpkg --compare-versions' "${G_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'ge "26.04"' "${G_INSTALL_DIRECTORY}/core/lib.sh"
grep -q 'g_check_ubuntu_lts' "${G_INSTALL_DIRECTORY}/core/lib.sh"
grep -qF '!= "ubuntu"' "${G_INSTALL_DIRECTORY}/core/lib.sh"
if grep -q 'anduinos' "${G_INSTALL_DIRECTORY}/core/lib.sh"; then
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
    g_check_ubuntu_base
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
            g_check_ubuntu_base 2>&1
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
    t_pass "fn.os.base" "Ubuntu seul, 26.04 ou plus récent"
else
    t_fail "fn.os.base" "la base Ubuntu n'accepte pas 26.04 ou plus récent"
fi
if grep -q '!= "26.04"' "${T_ROOT}/core/lib.sh"; then
    t_fail "fn.os.strict" "la version est comparée par égalité stricte sur VERSION_ID"
else
    t_pass "fn.os.strict" "la version est comparée au plancher 26.04"
fi

t_section "sshd -T casse"
if bash -s -- "${T_ROOT}" << 'SSHCASE'
set -euo pipefail
root="$1"
G_INSTALL_DIRECTORY="${root}"
# shellcheck disable=SC1091
source "${G_INSTALL_DIRECTORY}/core/lib.sh"
canon=$'Port 22\nPermitRootLogin no\nPasswordAuthentication yes\nAllowTcpForwarding no\n'
lower=$'port 2222\npermitrootlogin no\npasswordauthentication yes\n'
[[ "$(printf '%s\n' "${canon}" | g_read_sshd_value permitrootlogin)" == "no" ]]
[[ "$(printf '%s\n' "${canon}" | g_read_sshd_value PermitRootLogin)" == "no" ]]
[[ "$(printf '%s\n' "${canon}" | g_read_sshd_value port)" == "22" ]]
[[ "$(printf '%s\n' "${lower}" | g_read_sshd_value port)" == "2222" ]]
[[ "$(printf '%s\n' "${lower}" | g_read_sshd_value permitrootlogin)" == "no" ]]
grep -q 'g_get_sshd_value permitrootlogin' "${root}/service/ssh/configure.sh"
grep -q 'g_get_sshd_value permitrootlogin' "${root}/../server/service/ssh/configure.sh"
grep -q 'g_get_sshd_value allowtcpforwarding' "${root}/verify/workstation.sh"
grep -q 'tolower($1)=="permitrootlogin"' "${root}/service/cron/boot-check.sh"
if grep -RInE "awk '/\\^permitrootlogin " "${root}/service" "${root}/verify" "${root}/../server/service" >/dev/null 2>&1; then
    exit 1
fi
SSHCASE
then
    t_pass "fn.sshd.case" "sshd -T lu en minuscules et en casse canonique"
else
    t_fail "fn.sshd.case" "la lecture de sshd -T reste figée en minuscules"
fi

t_section "journaux dans logs/"
if grep -q 'trap g_install_exit EXIT' "${T_ROOT}/scripts/run.sh" \
   && grep -q 'G_LOG_DIR="${root}/logs/${name}"' "${MONO}/core/log.sh" \
   && grep -F -q '[[ "${code}" -ne 0 ]]' "${MONO}/core/log.sh"; then
    t_pass "logs.wire" "le poste écrit dans logs/ et copie les logiciels seulement en échec"
else
    t_fail "logs.wire" "journaux du poste encore hors de logs/, ou copie même en succès"
fi
t_require_function g_render_mail "${MONO}/core/mail.sh"
t_require_function g_install_mail_templates "${MONO}/core/mail.sh"

t_section "mode test du poste"
if grep -q '^G_MODE_TEST=1$' "${T_ROOT}/config/global.conf" \
   && ! grep -q '^S_SERVER_TYPE=' "${T_ROOT}/config/global.conf" \
   && grep -q '^G_MODE_TEST=${G_MODE_TEST}$' "${T_ROOT}/scripts/config-check.sh" \
   && ! grep -q 'S_SERVER_TYPE' "${T_ROOT}/scripts/config-check.sh" \
   && grep -q 'w_prompt G_MODE_TEST' "${T_ROOT}/scripts/configure.sh" \
   && grep -q 'bool01' "${T_ROOT}/scripts/configure.sh" \
   && ! grep -q 'S_SERVER_TYPE' "${T_ROOT}/scripts/run.sh" \
   && ! grep -RIn --include='*.sh' 'S_SERVER_TYPE' \
        "${T_ROOT}/system" "${T_ROOT}/service" "${T_ROOT}/verify" | grep -q . \
   && grep -q 'G_MODE_TEST:-0' "${MONO}/core/log.sh"; then
    t_pass "user.mode-test" "G_MODE_TEST=1, S_SERVER_TYPE absent du poste"
else
    t_fail "user.mode-test" "G_MODE_TEST ou S_SERVER_TYPE mal placé"
fi

stage="$(mktemp -d)"
if bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$1"
    w_set_config_default
    w_write_global_config "$2/global.conf"
    grep -q "^G_MODE_TEST=1$" "$2/global.conf"
    ! grep -q "^S_SERVER_TYPE=" "$2/global.conf"
' bash "${T_ROOT}/scripts/config-check.sh" "${stage}"; then
    t_pass "user.mode-test.write" "le fichier réécrit porte G_MODE_TEST=1, sans S_SERVER_TYPE"
else
    t_fail "user.mode-test.write" "la réécriture omet G_MODE_TEST ou garde S_SERVER_TYPE"
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
out="$(G_PRODUCT_ROOT="${T_ROOT}" bash -c '
    set -euo pipefail
    unset S_SERVER_TYPE || true
    # shellcheck disable=SC1090
    source "$1"
    g_run_step "$2" "one.sh"
    g_run_step "$2" MATRIX "two.sh"
' bash "${T_ROOT}/core/lib.sh" "${tree}" 2>/dev/null)" || out=""
if [[ "${out}" == "A:${tree}:"$'\n'"B:${tree}:MATRIX" ]]; then
    t_pass "user.mode-test.steps" "le poste lance l'étape sans profil, le serveur garde le sien"
else
    t_fail "user.mode-test.steps" "arguments reçus : ${out}"
fi
rm -rf "${tree}"

log_work="$(mktemp -d)"
if G_PRODUCT_ROOT="${T_ROOT}" bash -c '
    set -euo pipefail
    unset S_SERVER_TYPE || true
    # shellcheck disable=SC1090
    source "$1"
    G_INSTALL_DIRECTORY="$2"
    export G_INSTALL_DIRECTORY
    W_PROJECT_SLUG=liltress-workstation
    G_PROJECT_NAME=HF
    unset UBUNTU_BASE_VERSION || true
    OS_PRETTY="Ubuntu"
    OS_VERSION_ID="26.10"
    export OS_PRETTY OS_VERSION_ID
    g_init_install_log
    [[ "${G_LOG_DIR}" == "${G_INSTALL_DIRECTORY}/logs/install-"*"-workstation" ]]
    grep -Fqx "os          : Ubuntu 26.10" "${G_LOG_DIR}/meta.txt"
    grep -Fqx "os          : Ubuntu 26.10" "${G_LOG_DIR}/install.log"
    OS_PRETTY="Ubuntu 26.10"
    export OS_PRETTY
    g_init_install_log
    grep -Fqx "os          : Ubuntu 26.10" "${G_LOG_DIR}/meta.txt"
    ! grep -Fqx "os          : Ubuntu 26.10 26.10" "${G_LOG_DIR}/meta.txt"
' bash "${T_ROOT}/core/lib.sh" "${log_work}"; then
    t_pass "user.mode-test.logname" "journal nommé install-*-workstation, version de distribution écrite une fois"
else
    t_fail "user.mode-test.logname" "le journal du poste omet -user ou la version de distribution"
fi
rm -rf "${log_work}"

if timeout 3 bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    source "$1"
    unset G_INSTALL_DIRECTORY || true
    # shellcheck disable=SC1090
    source "$2"
    [[ "${G_MODE_TEST}" == "1" ]]
    [[ -z "${S_SERVER_TYPE:-}" ]]
    work="$(mktemp -d)"
    trap "rm -rf -- \"${work}\"" EXIT
    mkdir -p "${work}/inst/scripts" "${work}/inst/config" "${work}/base"
    printf x > "${work}/inst/hf"
    printf x > "${work}/inst/scripts/run.sh"
    printf C > "${work}/inst/config/global.conf"
    inst="$(cd -- "${work}/inst" && pwd -P)"
    base="$(cd -- "${work}/base" && pwd -P)"
    out="$(G_INSTALL_DIRECTORY="${inst}" G_CONFIG_BASE_DIRECTORY="${base}" g_offer_remove_installer 2>&1)"
    [[ "${out}" != *[Ss]upprimer* ]]
    [[ -f "${inst}/hf" && -f "${inst}/config/global.conf" ]]
' bash "${MONO}/core/log.sh" "${T_ROOT}/config/global.conf"; then
    t_pass "user.mode-test.skip" "G_MODE_TEST=1 termine sans question"
else
    t_fail "user.mode-test.skip" "la question de suppression part encore"
fi
