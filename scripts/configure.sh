#!/usr/bin/env bash
# =============================================================================
# File       : scripts/configure.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

set -euo pipefail

DIR_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/scripts/config-check.sh"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/core/lib.sh"

usage() {
    cat << 'EOF'
Usage :
  sudo ./hf configure          questions, puis l'installation
  ./hf check                   contrôle les fichiers, code 0 si conformes

Le jeton Ubuntu Pro est obligatoire. Les alertes e-mail sont au choix.
Un mot de passe s'affiche en astérisques, puis une seconde ligne demande la confirmation.
EOF
}

hfu_read_stars() {
    local __out="$1"
    local char="" buf=""
    while true; do
        IFS= read -r -s -n 1 char || error "Entrée interrompue"
        if [[ -z "${char}" || "${char}" == $'\n' ]]; then
            printf '\n' >&2
            break
        fi
        if [[ "${char}" == $'\177' || "${char}" == $'\b' ]]; then
            if [[ -n "${buf}" ]]; then
                buf="${buf%?}"
                printf '\b \b' >&2
            fi
            continue
        fi
        buf+="${char}"
        printf '*' >&2
    done
    printf -v "${__out}" '%s' "${buf}"
}

hfu_secret_line() {
    local label="$1" dest="$2" width="$3"
    printf '         \e[34m%*s\e[0m : ' "${width}" "${label}" >&2
    hfu_read_stars "${dest}"
}

hfu_prompt() {
    local __var="$1" __label="$2" __example="$3" __default="$4" __kind="$5" __hint="$6"
    local value="" confirm="" attempt current="" width
    current="${!__var:-}"
    [[ -n "${current}" ]] && __default="${current}"
    for attempt in 1 2 3; do
        echo ""
        if [[ "${__kind}" == "pro_token" || "${__kind}" == "secret" ]]; then
            width="${#__label}"
            [[ "${width}" -lt 12 ]] && width=12
            hfu_secret_line "${__label}" value "${width}"
            value="${value// /}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
            else
                hfu_secret_line "Confirmation" confirm "${width}"
                confirm="${confirm// /}"
                if [[ "${value}" != "${confirm}" ]]; then
                    echo ""
                    warn "Les deux saisies sont différentes."
                    continue
                fi
            fi
        else
            width="${#__label}"
            [[ "${width}" -lt 12 ]] && width=12
            printf '         \e[34m%*s\e[0m : ' "${width}" "${__label}" >&2
            IFS= read -r value || error "Entrée interrompue"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
            fi
        fi
        local ok=0
        case "${__kind}" in
            pro_token) hfu_is_pro_token "${value}" && ok=1 ;;
            email) hfu_is_email "${value}" && ok=1 ;;
            secret) hfu_is_secret "${value}" && ok=1 ;;
            smtp) hfu_is_smtp "${value}" && ok=1 ;;
            bool01) [[ "${value}" =~ ^[01]$ ]] && ok=1 ;;
        esac
        if [[ "${ok}" == "1" ]]; then
            printf -v "${__var}" '%s' "${value}"
            return 0
        fi
        echo ""
        warn "${__hint}"
    done
    error "${__label} — trois essais sans réponse acceptée. Exemple : ${__example}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
    info "Contrôle de la configuration"
    if hfu_require_prepared_config "${DIR_SCRIPT}"; then
        success "Configuration conforme"
        exit 0
    fi
    exit 1
fi

if [[ -n "${1:-}" || $# -gt 0 ]]; then
    usage >&2
    exit 2
fi

if [[ ! -t 0 ]]; then
    if [[ ! -r /dev/tty ]]; then
        error "Pas de terminal pour les questions. Lancez : sudo bash ${DIR_SCRIPT}/hf configure"
    fi
    exec </dev/tty
fi

require_root
clear

hfu_config_set_builtin_defaults

_saved_dir_set=0
_saved_dir=""
if [[ -n "${DIR_INSTALL_PATH+x}" ]]; then
    _saved_dir_set=1
    _saved_dir="${DIR_INSTALL_PATH}"
    unset DIR_INSTALL_PATH || true
fi
if [[ -f "${DIR_SCRIPT}/config/global.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/config/global.conf"
    set -u
fi
if [[ "${_saved_dir_set}" == "1" ]]; then
    DIR_INSTALL_PATH="${_saved_dir}"
fi
unset _saved_dir _saved_dir_set
if [[ -f "${DIR_SCRIPT}/config/secrets.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/config/secrets.conf"
    set -u
fi

violet "═════════════════════════════════════════════════════════════════════════════════"
violet " High-Fortress User — configuration                                               "
violet "═════════════════════════════════════════════════════════════════════════════════"

title "Jeton Ubuntu Pro"
info "Jeton : https://ubuntu.com/pro/dashboard"
info "Lettres et chiffres, sans espace."
hfu_prompt UBUNTU_PRO_TOKEN \
    "Jeton Ubuntu Pro" \
    "C1abcdefghij1234567890" \
    "" \
    pro_token \
    "Lettres et chiffres seulement, entre 6 et 100, sans espace."

hfu_clear_mail() {
    POSTFIX_SMTP_LOGIN=""
    POSTFIX_MAIL_ADDRESS=""
    POSTFIX_MAIL_PASS=""
    POSTFIX_MAIL_SMTP=""
    WATCHDOG_MAIL=""
}

hfu_swaks_probe() {
    local out="" rc=0 safe=""
    if ! command -v swaks >/dev/null 2>&1; then
        info "Installation de swaks pour l'essai d'envoi."
        run_silent_apt install -y swaks
    fi
    out="$(swaks \
        --to "${POSTFIX_MAIL_ADDRESS}" \
        --from "${POSTFIX_MAIL_ADDRESS}" \
        --server "${POSTFIX_MAIL_SMTP}" \
        --auth LOGIN \
        --auth-user "${POSTFIX_SMTP_LOGIN}" \
        --auth-password "${POSTFIX_MAIL_PASS}" \
        --tls \
        --timeout 25 \
        2>&1)" || rc=$?
    safe="${out//${POSTFIX_MAIL_PASS}/[masqué]}"
    if [[ "${rc}" -eq 0 ]] && printf '%s\n' "${safe}" | grep -qE '(^|[^0-9])250([^0-9]|$)'; then
        return 0
    fi
    echo ""
    warn "Les données e-mail ne sont pas bonnes."
    printf '%s\n' "${safe}" | tail -n 12 >&2
    return 1
}

title "Alertes par e-mail"
info "Activer les alertes par e-mails (Y/N)."
while true; do
    echo ""
    printf '         \e[34m%*s\e[0m : ' 12 "Activer" >&2
    IFS= read -r mail_choice || error "Entrée interrompue"
    case "${mail_choice,,}" in
        Y|y)
            hfu_clear_mail

            title "Serveur SMTP"
            info "Forme hôte:port, par exemple smtp-mail.outlook.com:587."
            hfu_prompt POSTFIX_MAIL_SMTP \
                "Serveur" \
                "smtp-mail.outlook.com:587" \
                "" \
                smtp \
                "Indiquez le serveur et le port, sans crochets. Exemple : smtp-mail.outlook.com:587."

            title "Login SMTP"
            info "Adresse email servant de login."
            hfu_prompt POSTFIX_SMTP_LOGIN \
                "Login" \
                "toi@exemple.com" \
                "" \
                email \
                "Indiquez l'adresse e-mail du compte SMTP."

            title "Mot de passe d'application"
            info "Espaces retirés. La ligne suivante confirme."
            hfu_prompt POSTFIX_MAIL_PASS \
                "Password" \
                "mot-de-passe-application" \
                "" \
                secret \
                "Mot de passe d'application : au moins 8 caractères, sans espace."

            title "Expéditeur"
            info "Les alertes partent vers cette même adresse."
            hfu_prompt POSTFIX_MAIL_ADDRESS \
                "From" \
                "toi@exemple.com" \
                "" \
                email \
                "Indiquez l'adresse e-mail expéditeur."
            WATCHDOG_MAIL="${POSTFIX_MAIL_ADDRESS}"

            title "Essai d'envoi"
            info "Essai d'envoi (swaks vérifie serveur, login, mot de passe et expéditeur)"
            if hfu_swaks_probe; then
                HF_MAIL_ALERTS=1
                success "Essai d'envoi accepté."
                break
            fi
            hfu_clear_mail
            info "Retour au choix des alertes."
            ;;
        n|non)
            info "Coupure des alertes e-mail"
            hfu_clear_mail
            HF_MAIL_ALERTS=0
            success "Alertes e-mail coupées. Les contrôles partiront sans envoi."
            break
            ;;
        *)
            warn "Répondez Y ou n."
            ;;
    esac
done

title "Mode test"
info "1 : pas de retrait. 0 : question en fin d'installation."
info "Entrée conserve la valeur en cours (1 par défaut)."
hfu_prompt MODE_TEST \
    "Mode test" \
    "1" \
    "${MODE_TEST:-1}" \
    bool01 \
    "Indiquez 0 ou 1."

info "Enregistrement de la configuration"
mkdir -p "${DIR_SCRIPT}/config"
hfu_write_global_conf "${DIR_SCRIPT}/config/global.conf"
hfu_write_secrets_conf "${DIR_SCRIPT}/config/secrets.conf"

if ! hfu_require_prepared_config "${DIR_SCRIPT}"; then
    error "Les fichiers écrits ne passent pas le contrôle."
fi

success "Configuration enregistrée"
exec bash "${DIR_SCRIPT}/scripts/run.sh"
echo ""
