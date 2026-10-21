#!/usr/bin/env bash
# =============================================================================
# File       : scripts/config-check.sh
# Updated at : 2026-10-20
# Creator    : palarchsys
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'Utilisez : ./hf configure [--check]\n' >&2
    exit 1
fi

HF_PRODUCT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${HF_PRODUCT_ROOT}/../core/bootstrap.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HF_PRODUCT_ROOT}/../core/bootstrap.sh"
elif [[ -f "${HF_PRODUCT_ROOT}/core/bootstrap.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HF_PRODUCT_ROOT}/core/bootstrap.sh"
else
    printf 'bootstrap core introuvable depuis %s\n' "${HF_PRODUCT_ROOT}" >&2
    exit 1
fi
hf_source_core config-validators.sh

HFU_CONFIG_ERRORS=()

hfu_reset_config() {
    HFU_CONFIG_ERRORS=()
}

hfu_log_config_error() {
    HFU_CONFIG_ERRORS+=("$1")
}

hfu_emit_config() {
    local e
    if [[ ${#HFU_CONFIG_ERRORS[@]} -eq 0 ]]; then
        return 0
    fi
    for e in "${HFU_CONFIG_ERRORS[@]}"; do
        printf 'ERREUR: %s\n' "${e}" >&2
    done
    return 1
}

hfu_check_pro_token() {
    [[ "$1" =~ ^[A-Za-z0-9]{6,100}$ ]]
}

hfu_set_config_default() {
    : "${HF_PROJECT_NAME:=High-Fortress User}"
    : "${HFU_PROJECT_SLUG:=high-fortress-user}"
    : "${HF_PROJECT_VERSION:=0.2}"
    : "${HF_DEBUG_INSTALL_LOG:=0}"
    : "${HF_MODE_TEST:=1}"
    : "${HF_LYNIS_MIN_SCORE:=80}"
    : "${HFU_OS_ID:=ubuntu}"
    : "${HFU_OS_VERSION:=26.04}"
    : "${HF_SSH_BANNER_PATH:=/etc/ssh/sshd_banner}"
    : "${HF_SSH_SERVICE_NAME:=ssh}"
    : "${HF_SSH_MAX_AUTH_TRIES:=4}"
    : "${HF_SSH_CLIENT_ALIVE_INTERVAL:=300}"
    : "${HF_SSH_CLIENT_ALIVE_COUNT_MAX:=2}"
    : "${HFU_SSH_LOGIN_GRACE_TIME:=30}"
    : "${HFU_PAM_PASSWORD_MIN_LENGTH:=12}"
    : "${HFU_FAILLOCK_DENY:=8}"
    : "${HFU_FAILLOCK_UNLOCK:=600}"
    : "${HFU_FAILLOCK_FAIL_INTERVAL:=900}"
    : "${HF_WATCHDOG_CPU_LIMIT:=50}"
    : "${HF_WATCHDOG_LIMIT_NICE:=19}"
    : "${HF_WATCHDOG_LIMIT_IO_NICE:=3}"
    : "${HF_UBUNTU_PRO_TOKEN:=}"
    : "${HF_MAIL_ALERTS:=0}"
    : "${HF_MAIL_TEMPLATE:=mail.html}"
    : "${HF_POSTFIX_SMTP_LOGIN:=}"
    : "${HF_POSTFIX_MAIL_ADDRESS:=}"
    : "${HF_POSTFIX_MAIL_PASSWORD:=}"
    : "${HF_POSTFIX_MAIL_SMTP:=}"
    : "${HF_WATCHDOG_MAIL:=}"
    if [[ -z "${HF_BANNER_MESSAGE:-}" ]]; then
        HF_BANNER_MESSAGE="***********************************************************************
*                                                                     *
* This system is the property of its owner.                           *
* Unauthorized access is strictly prohibited and will be prosecuted.  *
*                                                                     *
* All access, activities, and communications on this system are       *
* monitored, recorded, and may be disclosed to authorized parties.    *
* By proceeding, you consent to this monitoring.                      *
*                                                                     *
* Any unauthorized use may result in civil and/or criminal penalties  *
* under applicable laws.                                              *
*                                                                     *
* Unauthorized users: Disconnect immediately.                         *
*                                                                     *
***********************************************************************"
    fi
}

hfu_write_global_config() {
    local dest="$1"
    cat > "${dest}" << EOF
# =============================================================================
# File       : config/global.conf
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

# Shared

HF_CONFIG_PREPARED=1

HF_PROJECT_NAME="${HF_PROJECT_NAME}"
HF_PROJECT_VERSION="${HF_PROJECT_VERSION}"

HF_CONFIG_BASE_DIRECTORY="/opt/high-fortress-user"
HF_SECRET_DIRECTORY="\${HF_CONFIG_BASE_DIRECTORY}/secrets"

HF_DEBUG_INSTALL_LOG=${HF_DEBUG_INSTALL_LOG}

HF_MODE_TEST=${HF_MODE_TEST}

HF_LYNIS_MIN_SCORE=${HF_LYNIS_MIN_SCORE}

HF_BANNER_MESSAGE="${HF_BANNER_MESSAGE}"

HF_SSH_BANNER_PATH="${HF_SSH_BANNER_PATH}"
HF_SSH_SERVICE_NAME="${HF_SSH_SERVICE_NAME}"
HF_SSH_MAX_AUTH_TRIES=${HF_SSH_MAX_AUTH_TRIES}
HF_SSH_CLIENT_ALIVE_INTERVAL=${HF_SSH_CLIENT_ALIVE_INTERVAL}
HF_SSH_CLIENT_ALIVE_COUNT_MAX=${HF_SSH_CLIENT_ALIVE_COUNT_MAX}

HF_WATCHDOG_CPU_LIMIT=${HF_WATCHDOG_CPU_LIMIT}
HF_WATCHDOG_LIMIT_NICE=${HF_WATCHDOG_LIMIT_NICE}
HF_WATCHDOG_LIMIT_IO_NICE=${HF_WATCHDOG_LIMIT_IO_NICE}

HF_MAIL_ALERTS=${HF_MAIL_ALERTS}

HF_MAIL_TEMPLATE="${HF_MAIL_TEMPLATE}"

# Server

# Workstation

HFU_PROJECT_SLUG="${HFU_PROJECT_SLUG}"

HFU_OS_ID="${HFU_OS_ID}"
HFU_OS_VERSION="${HFU_OS_VERSION}"

HFU_SSH_LOGIN_GRACE_TIME=${HFU_SSH_LOGIN_GRACE_TIME}

HFU_PAM_PASSWORD_MIN_LENGTH=${HFU_PAM_PASSWORD_MIN_LENGTH}
HFU_FAILLOCK_DENY=${HFU_FAILLOCK_DENY}
HFU_FAILLOCK_UNLOCK=${HFU_FAILLOCK_UNLOCK}
HFU_FAILLOCK_FAIL_INTERVAL=${HFU_FAILLOCK_FAIL_INTERVAL}

if [[ -n "\${HF_INSTALL_DIRECTORY:-}" && -f "\${HF_INSTALL_DIRECTORY}/config/secrets.conf" ]]; then
    # shellcheck disable=SC1091
    source "\${HF_INSTALL_DIRECTORY}/config/secrets.conf"
fi
EOF
    chmod 644 "${dest}"
}

hfu_write_secret_config() {
    local dest="$1"
    local old_umask
    old_umask="$(umask)"
    umask 077
    cat > "${dest}" << EOF
# =============================================================================
# File       : config/secrets.conf
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

# Shared

HF_SECRET_PREPARED=1
HF_UBUNTU_PRO_TOKEN="${HF_UBUNTU_PRO_TOKEN}"
HF_POSTFIX_SMTP_LOGIN="${HF_POSTFIX_SMTP_LOGIN}"
HF_POSTFIX_MAIL_ADDRESS="${HF_POSTFIX_MAIL_ADDRESS}"
HF_POSTFIX_MAIL_PASSWORD="${HF_POSTFIX_MAIL_PASSWORD}"
HF_POSTFIX_MAIL_SMTP="${HF_POSTFIX_MAIL_SMTP}"
HF_WATCHDOG_MAIL="${HF_WATCHDOG_MAIL}"

# Server

# Workstation
EOF
    chmod 600 "${dest}"
    umask "${old_umask}"
}

hfu_scan_config_dollar() {
    local file="$1" label="$2" stripped
    if grep -q '`' "${file}"; then
        hfu_log_config_error "${label} : apostrophe inverse interdite."
    fi
    if grep -q '\$(' "${file}"; then
        hfu_log_config_error "${label} : \$(...) interdit."
    fi
    stripped="$(sed -E \
        -e 's/\$\{HF_INSTALL_DIRECTORY:-\}//g' \
        -e 's/\$\{HF_INSTALL_DIRECTORY\}//g' \
        -e 's/\$\{HFU_PROJECT_SLUG\}//g' \
        -e 's/\$\{HF_CONFIG_BASE_DIRECTORY\}//g' \
        "${file}")"
    if grep -q '\$' <<< "${stripped}"; then
        hfu_log_config_error "${label} : dollar hors références autorisées (HFU_PROJECT_SLUG, HF_CONFIG_BASE_DIRECTORY, HF_INSTALL_DIRECTORY)."
    fi
}

hfu_validate_values() {
    local label_g="global.conf" label_s="secrets.conf"

    [[ "${HF_CONFIG_PREPARED:-}" == "1" ]] || hfu_log_config_error "${label_g} : HF_CONFIG_PREPARED doit valoir 1. exemple : ./hf configure"
    [[ "${HF_PROJECT_NAME:-}" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]{0,62}$ ]] || hfu_log_config_error "${label_g} : HF_PROJECT_NAME invalide (« ${HF_PROJECT_NAME:-} »). exemple : High-Fortress User"
    [[ "${HFU_PROJECT_SLUG:-}" == "high-fortress-user" ]] || hfu_log_config_error "${label_g} : HFU_PROJECT_SLUG invalide (« ${HFU_PROJECT_SLUG:-} »). exemple : high-fortress-user"
    [[ "${HF_PROJECT_VERSION:-}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || hfu_log_config_error "${label_g} : HF_PROJECT_VERSION invalide (« ${HF_PROJECT_VERSION:-} »). exemple : 0.2"
    [[ "${HF_DEBUG_INSTALL_LOG:-}" =~ ^[01]$ ]] || hfu_log_config_error "${label_g} : HF_DEBUG_INSTALL_LOG invalide (« ${HF_DEBUG_INSTALL_LOG:-} »). exemple : 0"
    [[ "${HF_MODE_TEST:-}" =~ ^[01]$ ]] || hfu_log_config_error "${label_g} : HF_MODE_TEST invalide (« ${HF_MODE_TEST:-} »). exemple : 1"
    hf_check_port "${HF_LYNIS_MIN_SCORE:-x}" 0 100 || hfu_log_config_error "${label_g} : HF_LYNIS_MIN_SCORE invalide (« ${HF_LYNIS_MIN_SCORE:-} »). exemple : 80"
    [[ "${HFU_OS_ID:-}" == "ubuntu" ]] || hfu_log_config_error "${label_g} : HFU_OS_ID invalide (« ${HFU_OS_ID:-} »). exemple : ubuntu"
    [[ "${HFU_OS_VERSION:-}" == "26.04" ]] || hfu_log_config_error "${label_g} : HFU_OS_VERSION invalide (« ${HFU_OS_VERSION:-} »). exemple : 26.04"
    [[ -n "${HF_BANNER_MESSAGE:-}" && "${HF_BANNER_MESSAGE}" != *'$('* && "${HF_BANNER_MESSAGE}" != *'`'* ]] || hfu_log_config_error "${label_g} : HF_BANNER_MESSAGE vide ou non sûr."
    hf_check_absolute_path "${HF_SSH_BANNER_PATH:-}" || hfu_log_config_error "${label_g} : HF_SSH_BANNER_PATH invalide (« ${HF_SSH_BANNER_PATH:-} »). exemple : /etc/ssh/sshd_banner"
    [[ "${HF_SSH_SERVICE_NAME:-}" == "ssh" ]] || hfu_log_config_error "${label_g} : HF_SSH_SERVICE_NAME invalide (« ${HF_SSH_SERVICE_NAME:-} »). exemple : ssh"
    hf_check_port "${HF_SSH_MAX_AUTH_TRIES:-x}" 1 10 || hfu_log_config_error "${label_g} : HF_SSH_MAX_AUTH_TRIES invalide (« ${HF_SSH_MAX_AUTH_TRIES:-} »). exemple : 4"
    hf_check_port "${HF_SSH_CLIENT_ALIVE_INTERVAL:-x}" 30 3600 || hfu_log_config_error "${label_g} : HF_SSH_CLIENT_ALIVE_INTERVAL invalide (« ${HF_SSH_CLIENT_ALIVE_INTERVAL:-} »). exemple : 300"
    hf_check_port "${HF_SSH_CLIENT_ALIVE_COUNT_MAX:-x}" 1 10 || hfu_log_config_error "${label_g} : HF_SSH_CLIENT_ALIVE_COUNT_MAX invalide (« ${HF_SSH_CLIENT_ALIVE_COUNT_MAX:-} »). exemple : 2"
    hf_check_port "${HFU_SSH_LOGIN_GRACE_TIME:-x}" 10 120 || hfu_log_config_error "${label_g} : HFU_SSH_LOGIN_GRACE_TIME invalide (« ${HFU_SSH_LOGIN_GRACE_TIME:-} »). exemple : 30"
    hf_check_port "${HFU_PAM_PASSWORD_MIN_LENGTH:-x}" 8 32 || hfu_log_config_error "${label_g} : HFU_PAM_PASSWORD_MIN_LENGTH invalide (« ${HFU_PAM_PASSWORD_MIN_LENGTH:-} »). exemple : 12"
    hf_check_port "${HFU_FAILLOCK_DENY:-x}" 3 20 || hfu_log_config_error "${label_g} : HFU_FAILLOCK_DENY invalide (« ${HFU_FAILLOCK_DENY:-} »). exemple : 8"
    hf_check_port "${HFU_FAILLOCK_UNLOCK:-x}" 60 86400 || hfu_log_config_error "${label_g} : HFU_FAILLOCK_UNLOCK invalide (« ${HFU_FAILLOCK_UNLOCK:-} »). exemple : 600"
    hf_check_port "${HFU_FAILLOCK_FAIL_INTERVAL:-x}" 60 86400 || hfu_log_config_error "${label_g} : HFU_FAILLOCK_FAIL_INTERVAL invalide (« ${HFU_FAILLOCK_FAIL_INTERVAL:-} »). exemple : 900"
    hf_check_port "${HF_WATCHDOG_CPU_LIMIT:-x}" 1 100 || hfu_log_config_error "${label_g} : HF_WATCHDOG_CPU_LIMIT invalide (« ${HF_WATCHDOG_CPU_LIMIT:-} »). exemple : 50"
    hf_check_port "${HF_WATCHDOG_LIMIT_NICE:-x}" 0 19 || hfu_log_config_error "${label_g} : HF_WATCHDOG_LIMIT_NICE invalide (« ${HF_WATCHDOG_LIMIT_NICE:-} »). exemple : 19"
    hf_check_port "${HF_WATCHDOG_LIMIT_IO_NICE:-x}" 0 7 || hfu_log_config_error "${label_g} : HF_WATCHDOG_LIMIT_IO_NICE invalide (« ${HF_WATCHDOG_LIMIT_IO_NICE:-} »). exemple : 3"
    [[ "${HF_MAIL_ALERTS:-}" =~ ^[01]$ ]] || hfu_log_config_error "${label_g} : HF_MAIL_ALERTS invalide (« ${HF_MAIL_ALERTS:-} »). exemple : 0 ou 1"
    [[ "${HF_MAIL_TEMPLATE:-mail.html}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.html$ ]] || hfu_log_config_error "${label_g} : HF_MAIL_TEMPLATE invalide (« ${HF_MAIL_TEMPLATE:-} »). exemple : mail.html"
    if [[ -n "${HF_CONFIG_ROOT:-}" && -d "${HF_CONFIG_ROOT}/template" && ! -f "${HF_CONFIG_ROOT}/template/${HF_MAIL_TEMPLATE:-mail.html}" ]]; then
        hfu_log_config_error "${label_g} : HF_MAIL_TEMPLATE introuvable (${HF_MAIL_TEMPLATE:-mail.html}). exemple : un fichier .html du dossier template/"
    fi
    [[ "${HF_CONFIG_BASE_DIRECTORY:-}" == "/opt/high-fortress-user" ]] || hfu_log_config_error "${label_g} : HF_CONFIG_BASE_DIRECTORY invalide (« ${HF_CONFIG_BASE_DIRECTORY:-} »). exemple : /opt/high-fortress-user"
    [[ "${HF_SECRET_DIRECTORY:-}" == "/opt/high-fortress-user/secrets" ]] || hfu_log_config_error "${label_g} : HF_SECRET_DIRECTORY invalide (« ${HF_SECRET_DIRECTORY:-} »). exemple : /opt/high-fortress-user/secrets"

    [[ "${HF_SECRET_PREPARED:-}" == "1" ]] || hfu_log_config_error "${label_s} : HF_SECRET_PREPARED doit valoir 1. exemple : ./hf configure"
    hfu_check_pro_token "${HF_UBUNTU_PRO_TOKEN:-}" || hfu_log_config_error "${label_s} : HF_UBUNTU_PRO_TOKEN invalide. exemple : le jeton alphanumérique du tableau de bord Ubuntu Pro (https://ubuntu.com/pro/dashboard)"
    if [[ "${HF_MAIL_ALERTS}" == "1" ]]; then
        hf_check_email "${HF_POSTFIX_SMTP_LOGIN:-}" || hfu_log_config_error "${label_s} : HF_POSTFIX_SMTP_LOGIN doit être une adresse e-mail (« ${HF_POSTFIX_SMTP_LOGIN:-} »). exemple : toi@exemple.com"
        hf_check_email "${HF_POSTFIX_MAIL_ADDRESS:-}" || hfu_log_config_error "${label_s} : HF_POSTFIX_MAIL_ADDRESS doit être une adresse e-mail (« ${HF_POSTFIX_MAIL_ADDRESS:-} »). exemple : toi@exemple.com"
        hf_check_app_password "${HF_POSTFIX_MAIL_PASSWORD:-}" || hfu_log_config_error "${label_s} : HF_POSTFIX_MAIL_PASSWORD invalide. exemple : le mot de passe d'application du fournisseur, sans espace"
        hf_check_smtp "${HF_POSTFIX_MAIL_SMTP:-}" || hfu_log_config_error "${label_s} : HF_POSTFIX_MAIL_SMTP invalide (« ${HF_POSTFIX_MAIL_SMTP:-} »). exemple : smtp-mail.outlook.com:587"
        hf_check_email "${HF_WATCHDOG_MAIL:-}" || hfu_log_config_error "${label_s} : HF_WATCHDOG_MAIL doit être une adresse e-mail (« ${HF_WATCHDOG_MAIL:-} »). exemple : toi@exemple.com"
        [[ "${HF_WATCHDOG_MAIL:-}" == "${HF_POSTFIX_MAIL_ADDRESS:-}" ]] || hfu_log_config_error "${label_s} : HF_WATCHDOG_MAIL doit être la même adresse que HF_POSTFIX_MAIL_ADDRESS."
    else
        [[ -z "${HF_POSTFIX_SMTP_LOGIN:-}${HF_POSTFIX_MAIL_ADDRESS:-}${HF_POSTFIX_MAIL_PASSWORD:-}${HF_POSTFIX_MAIL_SMTP:-}${HF_WATCHDOG_MAIL:-}" ]] \
            || hfu_log_config_error "${label_s} : les champs e-mail doivent être vides quand les alertes sont coupées."
    fi
}

hfu_require_prepared_config() {
    local root="$1"
    local g="${root}/config/global.conf"
    local s="${root}/config/secrets.conf"
    local mode src_count

    hfu_reset_config

    if [[ ! -f "${g}" ]]; then
        hfu_log_config_error "global.conf absent (${g}). exemple : ./hf configure"
    fi
    if [[ ! -f "${s}" ]]; then
        hfu_log_config_error "secrets.conf absent (${s}). exemple : ./hf configure"
    fi
    if [[ ! -f "${g}" || ! -f "${s}" ]]; then
        hfu_emit_config
        return 1
    fi

    if ! bash -n "${g}" 2>/dev/null; then
        hfu_log_config_error "global.conf : syntaxe shell invalide. exemple : ./hf configure"
    fi
    if ! bash -n "${s}" 2>/dev/null; then
        hfu_log_config_error "secrets.conf : syntaxe shell invalide. exemple : ./hf configure"
    fi
    hfu_scan_config_dollar "${g}" "global.conf"
    hfu_scan_config_dollar "${s}" "secrets.conf"

    src_count="$(grep -cE '(^|[[:space:]])(source|\.)[[:space:]]' "${g}" || true)"
    if [[ "${src_count}" != "1" ]] || ! grep -q 'source "${HF_INSTALL_DIRECTORY}/config/secrets.conf"' "${g}"; then
        hfu_log_config_error "global.conf : la seule commande source autorisée charge secrets.conf. exemple : ./hf configure"
    fi
    if grep -qE '(^|[[:space:]])(source|\.)[[:space:]]' "${s}"; then
        hfu_log_config_error "secrets.conf : aucune commande source. exemple : uniquement des lignes CLE=\"valeur\""
    fi

    mode="$(stat -c '%a' "${s}" 2>/dev/null || echo '')"
    if [[ "${mode}" != "600" && "${mode}" != "400" ]]; then
        hfu_log_config_error "secrets.conf : permissions ${mode:-inconnues}, attendu 600. exemple : chmod 600 config/secrets.conf"
    fi

    if [[ ${#HFU_CONFIG_ERRORS[@]} -gt 0 ]]; then
        hfu_emit_config
        return 1
    fi

    set +u
    # shellcheck disable=SC1090
    source "${g}"
    # shellcheck disable=SC1090
    source "${s}"
    set -u

    HF_CONFIG_ROOT="${root}"
    hfu_validate_values
    hfu_emit_config
}
