#!/usr/bin/env bash
# =============================================================================
# File       : scripts/config-check.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'Utilisez : ./liltress configure [--check]\n' >&2
    exit 1
fi

G_PRODUCT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${G_PRODUCT_ROOT}/../core/bootstrap.sh" ]]; then
    # shellcheck disable=SC1091
    source "${G_PRODUCT_ROOT}/../core/bootstrap.sh"
elif [[ -f "${G_PRODUCT_ROOT}/core/bootstrap.sh" ]]; then
    # shellcheck disable=SC1091
    source "${G_PRODUCT_ROOT}/core/bootstrap.sh"
else
    printf 'bootstrap core introuvable depuis %s\n' "${G_PRODUCT_ROOT}" >&2
    exit 1
fi
g_source_core config-validators.sh

W_CONFIG_ERRORS=()

w_reset_config() {
    W_CONFIG_ERRORS=()
}

w_log_config_error() {
    W_CONFIG_ERRORS+=("$1")
}

w_emit_config() {
    local e
    if [[ ${#W_CONFIG_ERRORS[@]} -eq 0 ]]; then
        return 0
    fi
    for e in "${W_CONFIG_ERRORS[@]}"; do
        printf 'ERREUR: %s\n' "${e}" >&2
    done
    return 1
}

w_check_pro_token() {
    [[ "$1" =~ ^[A-Za-z0-9]{6,100}$ ]]
}

w_set_config_default() {
    : "${G_PROJECT_NAME:=Liltress Workstation}"
    : "${W_PROJECT_SLUG:=liltress-workstation}"
    : "${G_PROJECT_VERSION:=0.2}"
    : "${G_DEBUG_INSTALL_LOG:=0}"
    : "${G_MODE_TEST:=1}"
    : "${G_LYNIS_MIN_SCORE:=80}"
    : "${W_OS_ID:=ubuntu}"
    : "${W_OS_VERSION:=26.04}"
    : "${G_SSH_BANNER_PATH:=/etc/ssh/sshd_banner}"
    : "${G_SSH_SERVICE_NAME:=ssh}"
    : "${G_SSH_MAX_AUTH_TRIES:=4}"
    : "${G_SSH_CLIENT_ALIVE_INTERVAL:=300}"
    : "${G_SSH_CLIENT_ALIVE_COUNT_MAX:=2}"
    : "${W_SSH_LOGIN_GRACE_TIME:=30}"
    : "${W_PAM_PASSWORD_MIN_LENGTH:=12}"
    : "${W_FAILLOCK_DENY:=8}"
    : "${W_FAILLOCK_UNLOCK:=600}"
    : "${W_FAILLOCK_FAIL_INTERVAL:=900}"
    : "${G_WATCHDOG_CPU_LIMIT:=50}"
    : "${G_WATCHDOG_LIMIT_NICE:=19}"
    : "${G_WATCHDOG_LIMIT_IO_NICE:=3}"
    : "${G_UBUNTU_PRO_TOKEN:=}"
    : "${G_MAIL_ALERTS:=0}"
    : "${G_RCLONE_ALERTS:=0}"
    : "${G_RCLONE_REMOTE:=gdrive}"
    : "${G_RCLONE_PATH:=liltress-alerts}"
    : "${G_MAIL_TEMPLATE:=mail.html}"
    : "${G_POSTFIX_SMTP_LOGIN:=}"
    : "${G_POSTFIX_MAIL_ADDRESS:=}"
    : "${G_POSTFIX_MAIL_PASSWORD:=}"
    : "${G_POSTFIX_MAIL_SMTP:=}"
    : "${G_WATCHDOG_MAIL:=}"
    if [[ -z "${G_BANNER_MESSAGE:-}" ]]; then
        G_BANNER_MESSAGE="***********************************************************************
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

w_write_global_config() {
    local dest="$1"
    cat > "${dest}" << EOF
# =============================================================================
# File       : config/global.conf
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

# Shared

G_CONFIG_PREPARED=1

G_PROJECT_NAME="${G_PROJECT_NAME}"
G_PROJECT_VERSION="${G_PROJECT_VERSION}"

G_CONFIG_BASE_DIRECTORY="/opt/liltress-workstation"
G_SECRET_DIRECTORY="\${G_CONFIG_BASE_DIRECTORY}/secrets"

G_DEBUG_INSTALL_LOG=${G_DEBUG_INSTALL_LOG}

G_MODE_TEST=${G_MODE_TEST}

G_LYNIS_MIN_SCORE=${G_LYNIS_MIN_SCORE}

G_BANNER_MESSAGE="${G_BANNER_MESSAGE}"

G_SSH_BANNER_PATH="${G_SSH_BANNER_PATH}"
G_SSH_SERVICE_NAME="${G_SSH_SERVICE_NAME}"
G_SSH_MAX_AUTH_TRIES=${G_SSH_MAX_AUTH_TRIES}
G_SSH_CLIENT_ALIVE_INTERVAL=${G_SSH_CLIENT_ALIVE_INTERVAL}
G_SSH_CLIENT_ALIVE_COUNT_MAX=${G_SSH_CLIENT_ALIVE_COUNT_MAX}

G_WATCHDOG_CPU_LIMIT=${G_WATCHDOG_CPU_LIMIT}
G_WATCHDOG_LIMIT_NICE=${G_WATCHDOG_LIMIT_NICE}
G_WATCHDOG_LIMIT_IO_NICE=${G_WATCHDOG_LIMIT_IO_NICE}

G_MAIL_ALERTS=${G_MAIL_ALERTS}

G_RCLONE_ALERTS=${G_RCLONE_ALERTS}
G_RCLONE_REMOTE="${G_RCLONE_REMOTE}"
G_RCLONE_PATH="${G_RCLONE_PATH}"

G_MAIL_TEMPLATE="${G_MAIL_TEMPLATE}"

# Server

# Workstation

W_PROJECT_SLUG="${W_PROJECT_SLUG}"

W_OS_ID="${W_OS_ID}"
W_OS_VERSION="${W_OS_VERSION}"

W_SSH_LOGIN_GRACE_TIME=${W_SSH_LOGIN_GRACE_TIME}

W_PAM_PASSWORD_MIN_LENGTH=${W_PAM_PASSWORD_MIN_LENGTH}
W_FAILLOCK_DENY=${W_FAILLOCK_DENY}
W_FAILLOCK_UNLOCK=${W_FAILLOCK_UNLOCK}
W_FAILLOCK_FAIL_INTERVAL=${W_FAILLOCK_FAIL_INTERVAL}

if [[ -n "\${G_INSTALL_DIRECTORY:-}" && -f "\${G_INSTALL_DIRECTORY}/config/secrets.conf" ]]; then
    # shellcheck disable=SC1091
    source "\${G_INSTALL_DIRECTORY}/config/secrets.conf"
fi
EOF
    chmod 644 "${dest}"
}

w_write_secret_config() {
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

G_SECRET_PREPARED=1
G_UBUNTU_PRO_TOKEN="${G_UBUNTU_PRO_TOKEN}"
G_POSTFIX_SMTP_LOGIN="${G_POSTFIX_SMTP_LOGIN}"
G_POSTFIX_MAIL_ADDRESS="${G_POSTFIX_MAIL_ADDRESS}"
G_POSTFIX_MAIL_PASSWORD="${G_POSTFIX_MAIL_PASSWORD}"
G_POSTFIX_MAIL_SMTP="${G_POSTFIX_MAIL_SMTP}"
G_WATCHDOG_MAIL="${G_WATCHDOG_MAIL}"

# Server

# Workstation
EOF
    chmod 600 "${dest}"
    umask "${old_umask}"
}

w_scan_config_dollar() {
    local file="$1" label="$2" stripped
    if grep -q '`' "${file}"; then
        w_log_config_error "${label} : apostrophe inverse interdite."
    fi
    if grep -q '\$(' "${file}"; then
        w_log_config_error "${label} : \$(...) interdit."
    fi
    stripped="$(sed -E \
        -e 's/\$\{G_INSTALL_DIRECTORY:-\}//g' \
        -e 's/\$\{G_INSTALL_DIRECTORY\}//g' \
        -e 's/\$\{W_PROJECT_SLUG\}//g' \
        -e 's/\$\{G_CONFIG_BASE_DIRECTORY\}//g' \
        "${file}")"
    if grep -q '\$' <<< "${stripped}"; then
        w_log_config_error "${label} : dollar hors références autorisées (W_PROJECT_SLUG, G_CONFIG_BASE_DIRECTORY, G_INSTALL_DIRECTORY)."
    fi
}

w_validate_values() {
    local label_g="global.conf" label_s="secrets.conf"

    [[ "${G_CONFIG_PREPARED:-}" == "1" ]] || w_log_config_error "${label_g} : G_CONFIG_PREPARED doit valoir 1. exemple : ./liltress configure"
    [[ "${G_PROJECT_NAME:-}" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]{0,62}$ ]] || w_log_config_error "${label_g} : G_PROJECT_NAME invalide (« ${G_PROJECT_NAME:-} »). exemple : Liltress Workstation"
    [[ "${W_PROJECT_SLUG:-}" == "liltress-workstation" ]] || w_log_config_error "${label_g} : W_PROJECT_SLUG invalide (« ${W_PROJECT_SLUG:-} »). exemple : liltress-workstation"
    [[ "${G_PROJECT_VERSION:-}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || w_log_config_error "${label_g} : G_PROJECT_VERSION invalide (« ${G_PROJECT_VERSION:-} »). exemple : 0.2"
    [[ "${G_DEBUG_INSTALL_LOG:-}" =~ ^[01]$ ]] || w_log_config_error "${label_g} : G_DEBUG_INSTALL_LOG invalide (« ${G_DEBUG_INSTALL_LOG:-} »). exemple : 0"
    [[ "${G_MODE_TEST:-}" =~ ^[01]$ ]] || w_log_config_error "${label_g} : G_MODE_TEST invalide (« ${G_MODE_TEST:-} »). exemple : 1"
    g_check_port "${G_LYNIS_MIN_SCORE:-x}" 0 100 || w_log_config_error "${label_g} : G_LYNIS_MIN_SCORE invalide (« ${G_LYNIS_MIN_SCORE:-} »). exemple : 80"
    [[ "${W_OS_ID:-}" == "ubuntu" ]] || w_log_config_error "${label_g} : W_OS_ID invalide (« ${W_OS_ID:-} »). exemple : ubuntu"
    [[ "${W_OS_VERSION:-}" == "26.04" ]] || w_log_config_error "${label_g} : W_OS_VERSION invalide (« ${W_OS_VERSION:-} »). exemple : 26.04"
    [[ -n "${G_BANNER_MESSAGE:-}" && "${G_BANNER_MESSAGE}" != *'$('* && "${G_BANNER_MESSAGE}" != *'`'* ]] || w_log_config_error "${label_g} : G_BANNER_MESSAGE vide ou non sûr."
    g_check_absolute_path "${G_SSH_BANNER_PATH:-}" || w_log_config_error "${label_g} : G_SSH_BANNER_PATH invalide (« ${G_SSH_BANNER_PATH:-} »). exemple : /etc/ssh/sshd_banner"
    [[ "${G_SSH_SERVICE_NAME:-}" == "ssh" ]] || w_log_config_error "${label_g} : G_SSH_SERVICE_NAME invalide (« ${G_SSH_SERVICE_NAME:-} »). exemple : ssh"
    g_check_port "${G_SSH_MAX_AUTH_TRIES:-x}" 1 10 || w_log_config_error "${label_g} : G_SSH_MAX_AUTH_TRIES invalide (« ${G_SSH_MAX_AUTH_TRIES:-} »). exemple : 4"
    g_check_port "${G_SSH_CLIENT_ALIVE_INTERVAL:-x}" 30 3600 || w_log_config_error "${label_g} : G_SSH_CLIENT_ALIVE_INTERVAL invalide (« ${G_SSH_CLIENT_ALIVE_INTERVAL:-} »). exemple : 300"
    g_check_port "${G_SSH_CLIENT_ALIVE_COUNT_MAX:-x}" 1 10 || w_log_config_error "${label_g} : G_SSH_CLIENT_ALIVE_COUNT_MAX invalide (« ${G_SSH_CLIENT_ALIVE_COUNT_MAX:-} »). exemple : 2"
    g_check_port "${W_SSH_LOGIN_GRACE_TIME:-x}" 10 120 || w_log_config_error "${label_g} : W_SSH_LOGIN_GRACE_TIME invalide (« ${W_SSH_LOGIN_GRACE_TIME:-} »). exemple : 30"
    g_check_port "${W_PAM_PASSWORD_MIN_LENGTH:-x}" 8 32 || w_log_config_error "${label_g} : W_PAM_PASSWORD_MIN_LENGTH invalide (« ${W_PAM_PASSWORD_MIN_LENGTH:-} »). exemple : 12"
    g_check_port "${W_FAILLOCK_DENY:-x}" 3 20 || w_log_config_error "${label_g} : W_FAILLOCK_DENY invalide (« ${W_FAILLOCK_DENY:-} »). exemple : 8"
    g_check_port "${W_FAILLOCK_UNLOCK:-x}" 60 86400 || w_log_config_error "${label_g} : W_FAILLOCK_UNLOCK invalide (« ${W_FAILLOCK_UNLOCK:-} »). exemple : 600"
    g_check_port "${W_FAILLOCK_FAIL_INTERVAL:-x}" 60 86400 || w_log_config_error "${label_g} : W_FAILLOCK_FAIL_INTERVAL invalide (« ${W_FAILLOCK_FAIL_INTERVAL:-} »). exemple : 900"
    g_check_port "${G_WATCHDOG_CPU_LIMIT:-x}" 1 100 || w_log_config_error "${label_g} : G_WATCHDOG_CPU_LIMIT invalide (« ${G_WATCHDOG_CPU_LIMIT:-} »). exemple : 50"
    g_check_port "${G_WATCHDOG_LIMIT_NICE:-x}" 0 19 || w_log_config_error "${label_g} : G_WATCHDOG_LIMIT_NICE invalide (« ${G_WATCHDOG_LIMIT_NICE:-} »). exemple : 19"
    g_check_port "${G_WATCHDOG_LIMIT_IO_NICE:-x}" 0 7 || w_log_config_error "${label_g} : G_WATCHDOG_LIMIT_IO_NICE invalide (« ${G_WATCHDOG_LIMIT_IO_NICE:-} »). exemple : 3"
    [[ "${G_MAIL_ALERTS:-}" =~ ^[01]$ ]] || w_log_config_error "${label_g} : G_MAIL_ALERTS invalide (« ${G_MAIL_ALERTS:-} »). exemple : 0 ou 1"
    [[ "${G_RCLONE_ALERTS:-}" =~ ^[01]$ ]] || w_log_config_error "${label_g} : G_RCLONE_ALERTS invalide (« ${G_RCLONE_ALERTS:-} »). exemple : 0 ou 1"
    if [[ "${G_RCLONE_ALERTS:-0}" == "1" || -n "${G_RCLONE_REMOTE:-}" ]]; then
        g_check_drive_remote "${G_RCLONE_REMOTE:-}" || w_log_config_error "${label_g} : G_RCLONE_REMOTE invalide (« ${G_RCLONE_REMOTE:-} »). exemple : gdrive"
    fi
    if [[ "${G_RCLONE_ALERTS:-0}" == "1" || -n "${G_RCLONE_PATH:-}" ]]; then
        g_check_drive_path "${G_RCLONE_PATH:-}" || w_log_config_error "${label_g} : G_RCLONE_PATH invalide (« ${G_RCLONE_PATH:-} »). exemple : liltress-alerts"
    fi
    [[ "${G_MAIL_TEMPLATE:-mail.html}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.html$ ]] || w_log_config_error "${label_g} : G_MAIL_TEMPLATE invalide (« ${G_MAIL_TEMPLATE:-} »). exemple : mail.html"
    if [[ -n "${G_CONFIG_ROOT:-}" && -d "${G_CONFIG_ROOT}/template" && ! -f "${G_CONFIG_ROOT}/template/${G_MAIL_TEMPLATE:-mail.html}" ]]; then
        w_log_config_error "${label_g} : G_MAIL_TEMPLATE introuvable (${G_MAIL_TEMPLATE:-mail.html}). exemple : un fichier .html du dossier template/"
    fi
    [[ "${G_CONFIG_BASE_DIRECTORY:-}" == "/opt/liltress-workstation" ]] || w_log_config_error "${label_g} : G_CONFIG_BASE_DIRECTORY invalide (« ${G_CONFIG_BASE_DIRECTORY:-} »). exemple : /opt/liltress-workstation"
    [[ "${G_SECRET_DIRECTORY:-}" == "/opt/liltress-workstation/secrets" ]] || w_log_config_error "${label_g} : G_SECRET_DIRECTORY invalide (« ${G_SECRET_DIRECTORY:-} »). exemple : /opt/liltress-workstation/secrets"

    [[ "${G_SECRET_PREPARED:-}" == "1" ]] || w_log_config_error "${label_s} : G_SECRET_PREPARED doit valoir 1. exemple : ./liltress configure"
    w_check_pro_token "${G_UBUNTU_PRO_TOKEN:-}" || w_log_config_error "${label_s} : G_UBUNTU_PRO_TOKEN invalide. exemple : le jeton alphanumérique du tableau de bord Ubuntu Pro (https://ubuntu.com/pro/dashboard)"
    if [[ "${G_MAIL_ALERTS}" == "1" ]]; then
        g_check_email "${G_POSTFIX_SMTP_LOGIN:-}" || w_log_config_error "${label_s} : G_POSTFIX_SMTP_LOGIN doit être une adresse e-mail (« ${G_POSTFIX_SMTP_LOGIN:-} »). exemple : toi@exemple.com"
        g_check_email "${G_POSTFIX_MAIL_ADDRESS:-}" || w_log_config_error "${label_s} : G_POSTFIX_MAIL_ADDRESS doit être une adresse e-mail (« ${G_POSTFIX_MAIL_ADDRESS:-} »). exemple : toi@exemple.com"
        g_check_app_password "${G_POSTFIX_MAIL_PASSWORD:-}" || w_log_config_error "${label_s} : G_POSTFIX_MAIL_PASSWORD invalide. exemple : le mot de passe d'application du fournisseur, sans espace"
        g_check_smtp "${G_POSTFIX_MAIL_SMTP:-}" || w_log_config_error "${label_s} : G_POSTFIX_MAIL_SMTP invalide (« ${G_POSTFIX_MAIL_SMTP:-} »). exemple : smtp-mail.outlook.com:587"
        g_check_email "${G_WATCHDOG_MAIL:-}" || w_log_config_error "${label_s} : G_WATCHDOG_MAIL doit être une adresse e-mail (« ${G_WATCHDOG_MAIL:-} »). exemple : toi@exemple.com"
        [[ "${G_WATCHDOG_MAIL:-}" == "${G_POSTFIX_MAIL_ADDRESS:-}" ]] || w_log_config_error "${label_s} : G_WATCHDOG_MAIL doit être la même adresse que G_POSTFIX_MAIL_ADDRESS."
    else
        [[ -z "${G_POSTFIX_SMTP_LOGIN:-}${G_POSTFIX_MAIL_ADDRESS:-}${G_POSTFIX_MAIL_PASSWORD:-}${G_POSTFIX_MAIL_SMTP:-}${G_WATCHDOG_MAIL:-}" ]] \
            || w_log_config_error "${label_s} : les champs e-mail doivent être vides quand les alertes sont coupées."
    fi
}

w_require_prepared_config() {
    local root="$1"
    local g="${root}/config/global.conf"
    local s="${root}/config/secrets.conf"
    local mode src_count

    w_reset_config

    if [[ ! -f "${g}" ]]; then
        w_log_config_error "global.conf absent (${g}). exemple : ./liltress configure"
    fi
    if [[ ! -f "${s}" ]]; then
        w_log_config_error "secrets.conf absent (${s}). exemple : ./liltress configure"
    fi
    if [[ ! -f "${g}" || ! -f "${s}" ]]; then
        w_emit_config
        return 1
    fi

    if ! bash -n "${g}" 2>/dev/null; then
        w_log_config_error "global.conf : syntaxe shell invalide. exemple : ./liltress configure"
    fi
    if ! bash -n "${s}" 2>/dev/null; then
        w_log_config_error "secrets.conf : syntaxe shell invalide. exemple : ./liltress configure"
    fi
    w_scan_config_dollar "${g}" "global.conf"
    w_scan_config_dollar "${s}" "secrets.conf"

    src_count="$(grep -cE '(^|[[:space:]])(source|\.)[[:space:]]' "${g}" || true)"
    if [[ "${src_count}" != "1" ]] || ! grep -q 'source "${G_INSTALL_DIRECTORY}/config/secrets.conf"' "${g}"; then
        w_log_config_error "global.conf : la seule commande source autorisée charge secrets.conf. exemple : ./liltress configure"
    fi
    if grep -qE '(^|[[:space:]])(source|\.)[[:space:]]' "${s}"; then
        w_log_config_error "secrets.conf : aucune commande source. exemple : uniquement des lignes CLE=\"valeur\""
    fi

    mode="$(stat -c '%a' "${s}" 2>/dev/null || echo '')"
    if [[ "${mode}" != "600" && "${mode}" != "400" ]]; then
        w_log_config_error "secrets.conf : permissions ${mode:-inconnues}, attendu 600. exemple : chmod 600 config/secrets.conf"
    fi

    if [[ ${#W_CONFIG_ERRORS[@]} -gt 0 ]]; then
        w_emit_config
        return 1
    fi

    set +u
    # shellcheck disable=SC1090
    source "${g}"
    # shellcheck disable=SC1090
    source "${s}"
    set -u

    G_CONFIG_ROOT="${root}"
    w_validate_values
    w_emit_config
}
