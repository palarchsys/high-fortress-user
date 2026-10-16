#!/usr/bin/env bash
# =============================================================================
# File       : scripts/configure.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

set -euo pipefail

DIR_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/scripts/config-check.sh"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/core/lib.sh"

hfu_show_usage() {
    cat << 'EOF'
Usage :
  sudo ./hf configure          questions, puis l'installation
  ./hf check                   contrôle les fichiers, code 0 si conformes

Le jeton Ubuntu Pro est obligatoire. Les alertes e-mail sont au choix.
Un mot de passe s'affiche en astérisques, puis une seconde ligne demande la confirmation.
EOF
}

hfu_read_secret() {
    local __out="$1"
    local char="" buf=""
    while true; do
        IFS= read -r -s -n 1 char || hf_log_error "Entrée interrompue"
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

hfu_write_secret_line() {
    local label="$1" dest="$2" width="$3"
    printf '         \e[34m%*s\e[0m : ' "${width}" "${label}" >&2
    hfu_read_secret "${dest}"
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
            hfu_write_secret_line "${__label}" value "${width}"
            value="${value// /}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
            else
                hfu_write_secret_line "Confirmation" confirm "${width}"
                confirm="${confirm// /}"
                if [[ "${value}" != "${confirm}" ]]; then
                    echo ""
                    hf_log_warn "Les deux saisies sont différentes."
                    continue
                fi
            fi
        else
            width="${#__label}"
            [[ "${width}" -lt 12 ]] && width=12
            printf '         \e[34m%*s\e[0m : ' "${width}" "${__label}" >&2
            IFS= read -r value || hf_log_error "Entrée interrompue"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
            fi
        fi
        local ok=0
        case "${__kind}" in
            pro_token) hfu_check_pro_token "${value}" && ok=1 ;;
            email) hf_check_email "${value}" && ok=1 ;;
            secret) hf_check_app_password "${value}" && ok=1 ;;
            smtp) hf_check_smtp "${value}" && ok=1 ;;
            bool01) [[ "${value}" =~ ^[01]$ ]] && ok=1 ;;
        esac
        if [[ "${ok}" == "1" ]]; then
            printf -v "${__var}" '%s' "${value}"
            return 0
        fi
        echo ""
        hf_log_warn "${__hint}"
    done
    hf_log_error "${__label} — trois essais sans réponse acceptée. Exemple : ${__example}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    hfu_show_usage
    exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
    hf_log_info "Contrôle de la configuration"
    if hfu_require_prepared_config "${DIR_SCRIPT}"; then
        hf_log_success "Configuration conforme"
        exit 0
    fi
    exit 1
fi

if [[ -n "${1:-}" || $# -gt 0 ]]; then
    hfu_show_usage >&2
    exit 2
fi

if [[ ! -t 0 ]]; then
    if [[ ! -r /dev/tty ]]; then
        hf_log_error "Pas de terminal pour les questions. Lancez : sudo bash ${DIR_SCRIPT}/hf configure"
    fi
    exec </dev/tty
fi

hf_require_root
clear

hfu_set_config_default

_saved_dir_set=0
_saved_dir=""
if [[ -n "${HF_INSTALL_DIRECTORY+x}" ]]; then
    _saved_dir_set=1
    _saved_dir="${HF_INSTALL_DIRECTORY}"
    unset HF_INSTALL_DIRECTORY || true
fi
if [[ -f "${DIR_SCRIPT}/config/global.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/config/global.conf"
    set -u
fi
if [[ "${_saved_dir_set}" == "1" ]]; then
    HF_INSTALL_DIRECTORY="${_saved_dir}"
fi
unset _saved_dir _saved_dir_set
if [[ -f "${DIR_SCRIPT}/config/secrets.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/config/secrets.conf"
    set -u
fi

hf_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"
hf_set_color_violet " High-Fortress User — configuration                                               "
hf_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"

hf_log_title "Jeton Ubuntu Pro"
hf_log_info "Jeton : https://ubuntu.com/pro/dashboard"
hf_log_info "Lettres et chiffres, sans espace."
hfu_prompt HF_UBUNTU_PRO_TOKEN \
    "Jeton Ubuntu Pro" \
    "C1abcdefghij1234567890" \
    "" \
    pro_token \
    "Lettres et chiffres seulement, entre 6 et 100, sans espace."

hfu_clear_mail() {
    HF_POSTFIX_SMTP_LOGIN=""
    HF_POSTFIX_MAIL_ADDRESS=""
    HF_POSTFIX_MAIL_PASSWORD=""
    HF_POSTFIX_MAIL_SMTP=""
    HF_WATCHDOG_MAIL=""
}

hfu_check_smtp_probe() {
    local out="" rc=0 safe=""
    if ! command -v swaks >/dev/null 2>&1; then
        hf_log_info "Installation de swaks pour l'essai d'envoi."
        hf_run_silent_apt install -y swaks
    fi
    out="$(swaks \
        --to "${HF_POSTFIX_MAIL_ADDRESS}" \
        --from "${HF_POSTFIX_MAIL_ADDRESS}" \
        --server "${HF_POSTFIX_MAIL_SMTP}" \
        --auth LOGIN \
        --auth-user "${HF_POSTFIX_SMTP_LOGIN}" \
        --auth-password "${HF_POSTFIX_MAIL_PASSWORD}" \
        --tls \
        --timeout 25 \
        2>&1)" || rc=$?
    safe="${out//${HF_POSTFIX_MAIL_PASSWORD}/[masqué]}"
    if [[ "${rc}" -eq 0 ]] && printf '%s\n' "${safe}" | grep -qE '(^|[^0-9])250([^0-9]|$)'; then
        return 0
    fi
    echo ""
    hf_log_warn "Les données e-mail ne sont pas bonnes."
    printf '%s\n' "${safe}" | tail -n 12 >&2
    return 1
}

hf_log_title "Alertes par e-mail"
hf_log_info "Activer les alertes par e-mails (Y/N)."
while true; do
    echo ""
    printf '         \e[34m%*s\e[0m : ' 12 "Activer" >&2
    IFS= read -r mail_choice || hf_log_error "Entrée interrompue"
    case "${mail_choice,,}" in
        Y|y)
            hfu_clear_mail

            hf_log_title "Serveur SMTP"
            hf_log_info "Forme hôte:port, par exemple smtp-mail.outlook.com:587."
            hfu_prompt HF_POSTFIX_MAIL_SMTP \
                "Serveur" \
                "smtp-mail.outlook.com:587" \
                "" \
                smtp \
                "Indiquez le serveur et le port, sans crochets. Exemple : smtp-mail.outlook.com:587."

            hf_log_title "Login SMTP"
            hf_log_info "Adresse email servant de login."
            hfu_prompt HF_POSTFIX_SMTP_LOGIN \
                "Login" \
                "toi@exemple.com" \
                "" \
                email \
                "Indiquez l'adresse e-mail du compte SMTP."

            hf_log_title "Mot de passe d'application"
            hf_log_info "Espaces retirés. La ligne suivante confirme."
            hfu_prompt HF_POSTFIX_MAIL_PASSWORD \
                "Password" \
                "mot-de-passe-application" \
                "" \
                secret \
                "Mot de passe d'application : au moins 8 caractères, sans espace."

            hf_log_title "Expéditeur"
            hf_log_info "Les alertes partent vers cette même adresse."
            hfu_prompt HF_POSTFIX_MAIL_ADDRESS \
                "From" \
                "toi@exemple.com" \
                "" \
                email \
                "Indiquez l'adresse e-mail expéditeur."
            HF_WATCHDOG_MAIL="${HF_POSTFIX_MAIL_ADDRESS}"

            hf_log_title "Essai d'envoi"
            hf_log_info "Essai d'envoi (swaks vérifie serveur, login, mot de passe et expéditeur)"
            if hfu_check_smtp_probe; then
                HF_MAIL_ALERTS=1
                hf_log_success "Essai d'envoi accepté."
                break
            fi
            hfu_clear_mail
            hf_log_info "Retour au choix des alertes."
            ;;
        n|non)
            hf_log_info "Coupure des alertes e-mail"
            hfu_clear_mail
            HF_MAIL_ALERTS=0
            hf_log_success "Alertes e-mail coupées. Les contrôles partiront sans envoi."
            break
            ;;
        *)
            hf_log_warn "Répondez Y ou n."
            ;;
    esac
done

hf_log_title "Mode test"
hf_log_info "1 : pas de retrait. 0 : question en fin d'installation."
hf_log_info "Entrée conserve la valeur en cours (1 par défaut)."
hfu_prompt HF_MODE_TEST \
    "Mode test" \
    "1" \
    "${HF_MODE_TEST:-1}" \
    bool01 \
    "Indiquez 0 ou 1."

hf_log_info "Enregistrement de la configuration"
mkdir -p "${DIR_SCRIPT}/config"
hfu_write_global_config "${DIR_SCRIPT}/config/global.conf"
hfu_write_secret_config "${DIR_SCRIPT}/config/secrets.conf"

if ! hfu_require_prepared_config "${DIR_SCRIPT}"; then
    hf_log_error "Les fichiers écrits ne passent pas le contrôle."
fi

hf_log_success "Configuration enregistrée"
exec bash "${DIR_SCRIPT}/scripts/run.sh"
echo ""
