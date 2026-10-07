#!/usr/bin/env bash
# =============================================================================
# File       : scripts/config-check.sh
# Updated at : 2026-10-07
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

hfu_config_reset() {
    HFU_CONFIG_ERRORS=()
}

hfu_config_err() {
    HFU_CONFIG_ERRORS+=("$1")
}

hfu_config_emit() {
    local e
    if [[ ${#HFU_CONFIG_ERRORS[@]} -eq 0 ]]; then
        return 0
    fi
    for e in "${HFU_CONFIG_ERRORS[@]}"; do
        printf 'ERREUR: %s\n' "${e}" >&2
    done
    return 1
}

hfu_is_pro_token() {
    [[ "$1" =~ ^[A-Za-z0-9]{6,100}$ ]]
}

hfu_config_set_builtin_defaults() {
    : "${PROJECT_NAME:=High-Fortress User}"
    : "${PROJECT_SLUG:=high-fortress-user}"
    : "${PROJECT_VERSION:=0.2}"
    : "${DEBUG_INSTALL_LOGS:=0}"
    : "${MODE_TEST:=1}"
    : "${LYNIS_MIN_SCORE:=80}"
    : "${HFU_OS_ID:=ubuntu}"
    : "${HFU_OS_VERSION:=26.04}"
    : "${SSH_BANNER_PATH:=/etc/ssh/sshd_banner}"
    : "${SSH_SERVICE_NAME:=ssh}"
    : "${SSH_MAX_AUTH_TRIES:=4}"
    : "${SSH_CLIENT_ALIVE_INTERVAL:=300}"
    : "${SSH_CLIENT_ALIVE_COUNT_MAX:=2}"
    : "${SSH_LOGIN_GRACE_TIME:=30}"
    : "${PWQUALITY_MINLEN:=12}"
    : "${FAILLOCK_DENY:=8}"
    : "${FAILLOCK_UNLOCK:=600}"
    : "${FAILLOCK_FAIL_INTERVAL:=900}"
    : "${WATCHDOG_CPU_LIMIT:=20}"
    : "${WATCHDOG_LIMIT_NICE:=19}"
    : "${WATCHDOG_LIMIT_IONICE:=3}"
    : "${UBUNTU_PRO_TOKEN:=}"
    : "${HF_MAIL_ALERTS:=0}"
    : "${MAIL_TEMPLATE:=mail.html}"
    : "${POSTFIX_SMTP_LOGIN:=}"
    : "${POSTFIX_MAIL_ADDRESS:=}"
    : "${POSTFIX_MAIL_PASS:=}"
    : "${POSTFIX_MAIL_SMTP:=}"
    : "${WATCHDOG_MAIL:=}"
    if [[ -z "${BANNER_MESSAGE:-}" ]]; then
        BANNER_MESSAGE="***********************************************************************
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

hfu_write_global_conf() {
    local dest="$1"
    cat > "${dest}" << EOF
# =============================================================================
# File       : config/global.conf
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

HF_PREPARED=1

PROJECT_NAME="${PROJECT_NAME}"
PROJECT_SLUG="${PROJECT_SLUG}"
PROJECT_VERSION="${PROJECT_VERSION}"

CONFIG_BASE_DIR="/opt/\${PROJECT_SLUG}"
SECRETS_DIR="\${CONFIG_BASE_DIR}/secrets"

DEBUG_INSTALL_LOGS=${DEBUG_INSTALL_LOGS}

MODE_TEST=${MODE_TEST}

LYNIS_MIN_SCORE=${LYNIS_MIN_SCORE}

HFU_OS_ID="${HFU_OS_ID}"
HFU_OS_VERSION="${HFU_OS_VERSION}"

BANNER_MESSAGE="${BANNER_MESSAGE}"

SSH_BANNER_PATH="${SSH_BANNER_PATH}"
SSH_SERVICE_NAME="${SSH_SERVICE_NAME}"
SSH_MAX_AUTH_TRIES=${SSH_MAX_AUTH_TRIES}
SSH_CLIENT_ALIVE_INTERVAL=${SSH_CLIENT_ALIVE_INTERVAL}
SSH_CLIENT_ALIVE_COUNT_MAX=${SSH_CLIENT_ALIVE_COUNT_MAX}
SSH_LOGIN_GRACE_TIME=${SSH_LOGIN_GRACE_TIME}

PWQUALITY_MINLEN=${PWQUALITY_MINLEN}
FAILLOCK_DENY=${FAILLOCK_DENY}
FAILLOCK_UNLOCK=${FAILLOCK_UNLOCK}
FAILLOCK_FAIL_INTERVAL=${FAILLOCK_FAIL_INTERVAL}

WATCHDOG_CPU_LIMIT=${WATCHDOG_CPU_LIMIT}
WATCHDOG_LIMIT_NICE=${WATCHDOG_LIMIT_NICE}
WATCHDOG_LIMIT_IONICE=${WATCHDOG_LIMIT_IONICE}

HF_MAIL_ALERTS=${HF_MAIL_ALERTS}

MAIL_TEMPLATE="${MAIL_TEMPLATE}"

if [[ -n "\${DIR_INSTALL_PATH:-}" && -f "\${DIR_INSTALL_PATH}/config/secrets.conf" ]]; then
    # shellcheck disable=SC1091
    source "\${DIR_INSTALL_PATH}/config/secrets.conf"
fi
EOF
    chmod 644 "${dest}"
}

hfu_write_secrets_conf() {
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

HF_SECRETS_PREPARED=1
UBUNTU_PRO_TOKEN="${UBUNTU_PRO_TOKEN}"
POSTFIX_SMTP_LOGIN="${POSTFIX_SMTP_LOGIN}"
POSTFIX_MAIL_ADDRESS="${POSTFIX_MAIL_ADDRESS}"
POSTFIX_MAIL_PASS="${POSTFIX_MAIL_PASS}"
POSTFIX_MAIL_SMTP="${POSTFIX_MAIL_SMTP}"
WATCHDOG_MAIL="${WATCHDOG_MAIL}"
EOF
    chmod 600 "${dest}"
    umask "${old_umask}"
}

hfu_config_scan_dollars() {
    local file="$1" label="$2" stripped
    if grep -q '`' "${file}"; then
        hfu_config_err "${label} : apostrophe inverse interdite."
    fi
    if grep -q '\$(' "${file}"; then
        hfu_config_err "${label} : \$(...) interdit."
    fi
    stripped="$(sed -E \
        -e 's/\$\{DIR_INSTALL_PATH:-\}//g' \
        -e 's/\$\{DIR_INSTALL_PATH\}//g' \
        -e 's/\$\{PROJECT_SLUG\}//g' \
        -e 's/\$\{CONFIG_BASE_DIR\}//g' \
        "${file}")"
    if grep -q '\$' <<< "${stripped}"; then
        hfu_config_err "${label} : dollar hors références autorisées (PROJECT_SLUG, CONFIG_BASE_DIR, DIR_INSTALL_PATH)."
    fi
}

hfu_validate_values() {
    local label_g="global.conf" label_s="secrets.conf"

    [[ "${HF_PREPARED:-}" == "1" ]] || hfu_config_err "${label_g} : HF_PREPARED doit valoir 1. exemple : ./hf configure"
    [[ "${PROJECT_NAME:-}" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]{0,62}$ ]] || hfu_config_err "${label_g} : PROJECT_NAME invalide (« ${PROJECT_NAME:-} »). exemple : High-Fortress User"
    [[ "${PROJECT_SLUG:-}" == "high-fortress-user" ]] || hfu_config_err "${label_g} : PROJECT_SLUG invalide (« ${PROJECT_SLUG:-} »). exemple : high-fortress-user"
    [[ "${PROJECT_VERSION:-}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || hfu_config_err "${label_g} : PROJECT_VERSION invalide (« ${PROJECT_VERSION:-} »). exemple : 0.2"
    [[ "${DEBUG_INSTALL_LOGS:-}" =~ ^[01]$ ]] || hfu_config_err "${label_g} : DEBUG_INSTALL_LOGS invalide (« ${DEBUG_INSTALL_LOGS:-} »). exemple : 0"
    [[ "${MODE_TEST:-}" =~ ^[01]$ ]] || hfu_config_err "${label_g} : MODE_TEST invalide (« ${MODE_TEST:-} »). exemple : 1"
    hfu_is_port "${LYNIS_MIN_SCORE:-x}" 0 100 || hfu_config_err "${label_g} : LYNIS_MIN_SCORE invalide (« ${LYNIS_MIN_SCORE:-} »). exemple : 80"
    [[ "${HFU_OS_ID:-}" == "ubuntu" ]] || hfu_config_err "${label_g} : HFU_OS_ID invalide (« ${HFU_OS_ID:-} »). exemple : ubuntu"
    [[ "${HFU_OS_VERSION:-}" == "26.04" ]] || hfu_config_err "${label_g} : HFU_OS_VERSION invalide (« ${HFU_OS_VERSION:-} »). exemple : 26.04"
    [[ -n "${BANNER_MESSAGE:-}" && "${BANNER_MESSAGE}" != *'$('* && "${BANNER_MESSAGE}" != *'`'* ]] || hfu_config_err "${label_g} : BANNER_MESSAGE vide ou non sûr."
    hfu_is_abs_path "${SSH_BANNER_PATH:-}" || hfu_config_err "${label_g} : SSH_BANNER_PATH invalide (« ${SSH_BANNER_PATH:-} »). exemple : /etc/ssh/sshd_banner"
    [[ "${SSH_SERVICE_NAME:-}" == "ssh" ]] || hfu_config_err "${label_g} : SSH_SERVICE_NAME invalide (« ${SSH_SERVICE_NAME:-} »). exemple : ssh"
    hfu_is_port "${SSH_MAX_AUTH_TRIES:-x}" 1 10 || hfu_config_err "${label_g} : SSH_MAX_AUTH_TRIES invalide (« ${SSH_MAX_AUTH_TRIES:-} »). exemple : 4"
    hfu_is_port "${SSH_CLIENT_ALIVE_INTERVAL:-x}" 30 3600 || hfu_config_err "${label_g} : SSH_CLIENT_ALIVE_INTERVAL invalide (« ${SSH_CLIENT_ALIVE_INTERVAL:-} »). exemple : 300"
    hfu_is_port "${SSH_CLIENT_ALIVE_COUNT_MAX:-x}" 1 10 || hfu_config_err "${label_g} : SSH_CLIENT_ALIVE_COUNT_MAX invalide (« ${SSH_CLIENT_ALIVE_COUNT_MAX:-} »). exemple : 2"
    hfu_is_port "${SSH_LOGIN_GRACE_TIME:-x}" 10 120 || hfu_config_err "${label_g} : SSH_LOGIN_GRACE_TIME invalide (« ${SSH_LOGIN_GRACE_TIME:-} »). exemple : 30"
    hfu_is_port "${PWQUALITY_MINLEN:-x}" 8 32 || hfu_config_err "${label_g} : PWQUALITY_MINLEN invalide (« ${PWQUALITY_MINLEN:-} »). exemple : 12"
    hfu_is_port "${FAILLOCK_DENY:-x}" 3 20 || hfu_config_err "${label_g} : FAILLOCK_DENY invalide (« ${FAILLOCK_DENY:-} »). exemple : 8"
    hfu_is_port "${FAILLOCK_UNLOCK:-x}" 60 86400 || hfu_config_err "${label_g} : FAILLOCK_UNLOCK invalide (« ${FAILLOCK_UNLOCK:-} »). exemple : 600"
    hfu_is_port "${FAILLOCK_FAIL_INTERVAL:-x}" 60 86400 || hfu_config_err "${label_g} : FAILLOCK_FAIL_INTERVAL invalide (« ${FAILLOCK_FAIL_INTERVAL:-} »). exemple : 900"
    hfu_is_port "${WATCHDOG_CPU_LIMIT:-x}" 1 100 || hfu_config_err "${label_g} : WATCHDOG_CPU_LIMIT invalide (« ${WATCHDOG_CPU_LIMIT:-} »). exemple : 20"
    hfu_is_port "${WATCHDOG_LIMIT_NICE:-x}" 0 19 || hfu_config_err "${label_g} : WATCHDOG_LIMIT_NICE invalide (« ${WATCHDOG_LIMIT_NICE:-} »). exemple : 19"
    hfu_is_port "${WATCHDOG_LIMIT_IONICE:-x}" 0 7 || hfu_config_err "${label_g} : WATCHDOG_LIMIT_IONICE invalide (« ${WATCHDOG_LIMIT_IONICE:-} »). exemple : 3"
    [[ "${HF_MAIL_ALERTS:-}" =~ ^[01]$ ]] || hfu_config_err "${label_g} : HF_MAIL_ALERTS invalide (« ${HF_MAIL_ALERTS:-} »). exemple : 0 ou 1"
    [[ "${MAIL_TEMPLATE:-mail.html}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.html$ ]] || hfu_config_err "${label_g} : MAIL_TEMPLATE invalide (« ${MAIL_TEMPLATE:-} »). exemple : mail.html"
    if [[ -n "${HF_CONFIG_ROOT:-}" && -d "${HF_CONFIG_ROOT}/template" && ! -f "${HF_CONFIG_ROOT}/template/${MAIL_TEMPLATE:-mail.html}" ]]; then
        hfu_config_err "${label_g} : MAIL_TEMPLATE introuvable (${MAIL_TEMPLATE:-mail.html}). exemple : un fichier .html du dossier template/"
    fi
    [[ "${CONFIG_BASE_DIR:-}" == "/opt/high-fortress-user" ]] || hfu_config_err "${label_g} : CONFIG_BASE_DIR invalide (« ${CONFIG_BASE_DIR:-} »). exemple : /opt/high-fortress-user"
    [[ "${SECRETS_DIR:-}" == "/opt/high-fortress-user/secrets" ]] || hfu_config_err "${label_g} : SECRETS_DIR invalide (« ${SECRETS_DIR:-} »). exemple : /opt/high-fortress-user/secrets"

    [[ "${HF_SECRETS_PREPARED:-}" == "1" ]] || hfu_config_err "${label_s} : HF_SECRETS_PREPARED doit valoir 1. exemple : ./hf configure"
    hfu_is_pro_token "${UBUNTU_PRO_TOKEN:-}" || hfu_config_err "${label_s} : UBUNTU_PRO_TOKEN invalide. exemple : le jeton alphanumérique du tableau de bord Ubuntu Pro (https://ubuntu.com/pro/dashboard)"
    if [[ "${HF_MAIL_ALERTS}" == "1" ]]; then
        hfu_is_email "${POSTFIX_SMTP_LOGIN:-}" || hfu_config_err "${label_s} : POSTFIX_SMTP_LOGIN doit être une adresse e-mail (« ${POSTFIX_SMTP_LOGIN:-} »). exemple : toi@exemple.com"
        hfu_is_email "${POSTFIX_MAIL_ADDRESS:-}" || hfu_config_err "${label_s} : POSTFIX_MAIL_ADDRESS doit être une adresse e-mail (« ${POSTFIX_MAIL_ADDRESS:-} »). exemple : toi@exemple.com"
        hfu_is_secret "${POSTFIX_MAIL_PASS:-}" || hfu_config_err "${label_s} : POSTFIX_MAIL_PASS invalide. exemple : le mot de passe d'application du fournisseur, sans espace"
        hfu_is_smtp "${POSTFIX_MAIL_SMTP:-}" || hfu_config_err "${label_s} : POSTFIX_MAIL_SMTP invalide (« ${POSTFIX_MAIL_SMTP:-} »). exemple : smtp-mail.outlook.com:587"
        hfu_is_email "${WATCHDOG_MAIL:-}" || hfu_config_err "${label_s} : WATCHDOG_MAIL doit être une adresse e-mail (« ${WATCHDOG_MAIL:-} »). exemple : toi@exemple.com"
        [[ "${WATCHDOG_MAIL:-}" == "${POSTFIX_MAIL_ADDRESS:-}" ]] || hfu_config_err "${label_s} : WATCHDOG_MAIL doit être la même adresse que POSTFIX_MAIL_ADDRESS."
    else
        [[ -z "${POSTFIX_SMTP_LOGIN:-}${POSTFIX_MAIL_ADDRESS:-}${POSTFIX_MAIL_PASS:-}${POSTFIX_MAIL_SMTP:-}${WATCHDOG_MAIL:-}" ]] \
            || hfu_config_err "${label_s} : les champs e-mail doivent être vides quand les alertes sont coupées."
    fi
}

hfu_require_prepared_config() {
    local root="$1"
    local g="${root}/config/global.conf"
    local s="${root}/config/secrets.conf"
    local mode src_count

    hfu_config_reset

    if [[ ! -f "${g}" ]]; then
        hfu_config_err "global.conf absent (${g}). exemple : ./hf configure"
    fi
    if [[ ! -f "${s}" ]]; then
        hfu_config_err "secrets.conf absent (${s}). exemple : ./hf configure"
    fi
    if [[ ! -f "${g}" || ! -f "${s}" ]]; then
        hfu_config_emit
        return 1
    fi

    if ! bash -n "${g}" 2>/dev/null; then
        hfu_config_err "global.conf : syntaxe shell invalide. exemple : ./hf configure"
    fi
    if ! bash -n "${s}" 2>/dev/null; then
        hfu_config_err "secrets.conf : syntaxe shell invalide. exemple : ./hf configure"
    fi
    hfu_config_scan_dollars "${g}" "global.conf"
    hfu_config_scan_dollars "${s}" "secrets.conf"

    src_count="$(grep -cE '(^|[[:space:]])(source|\.)[[:space:]]' "${g}" || true)"
    if [[ "${src_count}" != "1" ]] || ! grep -q 'source "${DIR_INSTALL_PATH}/config/secrets.conf"' "${g}"; then
        hfu_config_err "global.conf : la seule commande source autorisée charge secrets.conf. exemple : ./hf configure"
    fi
    if grep -qE '(^|[[:space:]])(source|\.)[[:space:]]' "${s}"; then
        hfu_config_err "secrets.conf : aucune commande source. exemple : uniquement des lignes CLE=\"valeur\""
    fi

    mode="$(stat -c '%a' "${s}" 2>/dev/null || echo '')"
    if [[ "${mode}" != "600" && "${mode}" != "400" ]]; then
        hfu_config_err "secrets.conf : permissions ${mode:-inconnues}, attendu 600. exemple : chmod 600 config/secrets.conf"
    fi

    if [[ ${#HFU_CONFIG_ERRORS[@]} -gt 0 ]]; then
        hfu_config_emit
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
    hfu_config_emit
}
