#!/usr/bin/env bash
# =============================================================================
# File       : scripts/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

set -euo pipefail

DIR_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/scripts/config-check.sh"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/core/lib.sh"

w_show_usage() {
    cat << 'EOF'
Usage :
  sudo ./hf configure          questions, puis l'installation
  ./hf check                   contrôle les fichiers, code 0 si conformes

Le jeton Ubuntu Pro est obligatoire. Les alertes e-mail sont au choix.
L'envoi vers Google Drive est au choix. Coupé, rclone n'est pas installé.
Un mot de passe s'affiche en astérisques, puis une seconde ligne demande la confirmation.
EOF
}

w_read_secret() {
    local __out="$1"
    local char="" buf=""
    while true; do
        IFS= read -r -s -n 1 char || g_log_error "Entrée interrompue"
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

w_write_secret_line() {
    local label="$1" dest="$2" width="$3"
    printf '         \e[34m%*s\e[0m : ' "${width}" "${label}" >&2
    w_read_secret "${dest}"
}

w_prompt() {
    local __var="$1" __label="$2" __example="$3" __default="$4" __kind="$5" __hint="$6"
    local value="" confirm="" attempt current="" width
    current="${!__var:-}"
    [[ -n "${current}" ]] && __default="${current}"
    for attempt in 1 2 3; do
        echo ""
        if [[ "${__kind}" == "pro_token" || "${__kind}" == "secret" ]]; then
            width="${#__label}"
            [[ "${width}" -lt 12 ]] && width=12
            w_write_secret_line "${__label}" value "${width}"
            value="${value// /}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
            else
                w_write_secret_line "Confirmation" confirm "${width}"
                confirm="${confirm// /}"
                if [[ "${value}" != "${confirm}" ]]; then
                    echo ""
                    g_log_warn "Les deux saisies sont différentes."
                    continue
                fi
            fi
        else
            width="${#__label}"
            [[ "${width}" -lt 12 ]] && width=12
            printf '         \e[34m%*s\e[0m : ' "${width}" "${__label}" >&2
            IFS= read -r value || g_log_error "Entrée interrompue"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
            fi
        fi
        local ok=0
        case "${__kind}" in
            pro_token) w_check_pro_token "${value}" && ok=1 ;;
            email) g_check_email "${value}" && ok=1 ;;
            secret) g_check_app_password "${value}" && ok=1 ;;
            smtp) g_check_smtp "${value}" && ok=1 ;;
            bool01) [[ "${value}" =~ ^[01]$ ]] && ok=1 ;;
            remote) g_check_drive_remote "${value}" && ok=1 ;;
            drive_path) g_check_drive_path "${value}" && ok=1 ;;
        esac
        if [[ "${ok}" == "1" ]]; then
            printf -v "${__var}" '%s' "${value}"
            return 0
        fi
        echo ""
        g_log_warn "${__hint}"
    done
    g_log_error "${__label} — trois essais sans réponse acceptée. Exemple : ${__example}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    w_show_usage
    exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
    g_log_info "Contrôle de la configuration"
    if w_require_prepared_config "${DIR_SCRIPT}"; then
        g_log_success "Configuration conforme"
        exit 0
    fi
    exit 1
fi

if [[ -n "${1:-}" || $# -gt 0 ]]; then
    w_show_usage >&2
    exit 2
fi

if [[ ! -t 0 ]]; then
    if [[ ! -r /dev/tty ]]; then
        g_log_error "Pas de terminal pour les questions. Lancez : sudo bash ${DIR_SCRIPT}/hf configure"
    fi
    exec </dev/tty
fi

g_require_root
clear

w_set_config_default

_saved_dir_set=0
_saved_dir=""
if [[ -n "${G_INSTALL_DIRECTORY+x}" ]]; then
    _saved_dir_set=1
    _saved_dir="${G_INSTALL_DIRECTORY}"
    unset G_INSTALL_DIRECTORY || true
fi
if [[ -f "${DIR_SCRIPT}/config/global.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/config/global.conf"
    set -u
fi
if [[ "${_saved_dir_set}" == "1" ]]; then
    G_INSTALL_DIRECTORY="${_saved_dir}"
fi
unset _saved_dir _saved_dir_set
if [[ -f "${DIR_SCRIPT}/config/secrets.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/config/secrets.conf"
    set -u
fi

g_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"
g_set_color_violet " Liltress Workstation — configuration                                               "
g_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"

g_log_title "Jeton Ubuntu Pro"
g_log_info "Jeton : https://ubuntu.com/pro/dashboard"
g_log_info "Lettres et chiffres, sans espace."
w_prompt G_UBUNTU_PRO_TOKEN \
    "Jeton Ubuntu Pro" \
    "C1abcdefghij1234567890" \
    "" \
    pro_token \
    "Lettres et chiffres seulement, entre 6 et 100, sans espace."

w_clear_mail() {
    G_POSTFIX_SMTP_LOGIN=""
    G_POSTFIX_MAIL_ADDRESS=""
    G_POSTFIX_MAIL_PASSWORD=""
    G_POSTFIX_MAIL_SMTP=""
    G_WATCHDOG_MAIL=""
}

w_check_smtp_probe() {
    local out="" rc=0 safe=""
    if ! command -v swaks >/dev/null 2>&1; then
        g_log_info "Installation de swaks pour l'essai d'envoi."
        g_run_silent_apt install -y swaks
    fi
    out="$(swaks \
        --to "${G_POSTFIX_MAIL_ADDRESS}" \
        --from "${G_POSTFIX_MAIL_ADDRESS}" \
        --server "${G_POSTFIX_MAIL_SMTP}" \
        --auth LOGIN \
        --auth-user "${G_POSTFIX_SMTP_LOGIN}" \
        --auth-password "${G_POSTFIX_MAIL_PASSWORD}" \
        --tls \
        --timeout 25 \
        2>&1)" || rc=$?
    safe="${out//${G_POSTFIX_MAIL_PASSWORD}/[masqué]}"
    if [[ "${rc}" -eq 0 ]] && printf '%s\n' "${safe}" | grep -qE '(^|[^0-9])250([^0-9]|$)'; then
        return 0
    fi
    echo ""
    g_log_warn "Les données e-mail ne sont pas bonnes."
    printf '%s\n' "${safe}" | tail -n 12 >&2
    return 1
}

g_log_title "Alertes par e-mail"
g_log_info "Activer les alertes par e-mails (Y/N)."
while true; do
    echo ""
    printf '         \e[34m%*s\e[0m : ' 12 "Activer" >&2
    IFS= read -r mail_choice || g_log_error "Entrée interrompue"
    case "${mail_choice}" in
        Y|y)
            w_clear_mail

            g_log_title "Serveur SMTP"
            g_log_info "Forme hôte:port, par exemple smtp-mail.outlook.com:587."
            w_prompt G_POSTFIX_MAIL_SMTP \
                "Serveur" \
                "smtp-mail.outlook.com:587" \
                "" \
                smtp \
                "Indiquez le serveur et le port, sans crochets. Exemple : smtp-mail.outlook.com:587."

            g_log_title "Login SMTP"
            g_log_info "Adresse email servant de login."
            w_prompt G_POSTFIX_SMTP_LOGIN \
                "Login" \
                "toi@exemple.com" \
                "" \
                email \
                "Indiquez l'adresse e-mail du compte SMTP."

            g_log_title "Mot de passe d'application"
            g_log_info "Espaces retirés. La ligne suivante confirme."
            w_prompt G_POSTFIX_MAIL_PASSWORD \
                "Password" \
                "mot-de-passe-application" \
                "" \
                secret \
                "Mot de passe d'application : au moins 8 caractères, sans espace."

            g_log_title "Expéditeur"
            g_log_info "Les alertes partent vers cette même adresse."
            w_prompt G_POSTFIX_MAIL_ADDRESS \
                "From" \
                "toi@exemple.com" \
                "" \
                email \
                "Indiquez l'adresse e-mail expéditeur."
            G_WATCHDOG_MAIL="${G_POSTFIX_MAIL_ADDRESS}"

            g_log_title "Essai d'envoi"
            g_log_info "Essai d'envoi (swaks vérifie serveur, login, mot de passe et expéditeur)"
            if w_check_smtp_probe; then
                G_MAIL_ALERTS=1
                g_log_success "Essai d'envoi accepté."
                break
            fi
            w_clear_mail
            g_log_info "Retour au choix des alertes."
            ;;
        N|n|non)
            g_log_info "Coupure des alertes e-mail"
            w_clear_mail
            G_MAIL_ALERTS=0
            g_log_success "Alertes e-mail coupées. Les contrôles partiront sans envoi."
            break
            ;;
        *)
            g_log_warn "Répondez Y ou N."
            ;;
    esac
done

w_clear_drive() {
    local base
    G_RCLONE_ALERTS=0
    base="${G_CONFIG_BASE_DIRECTORY:-/opt/liltress-workstation}"
    rm -f "${base}/cron/rclone.conf"
}

w_ask_drive_alert() {
    local choice="" base config old_umask
    base="${G_CONFIG_BASE_DIRECTORY:-/opt/liltress-workstation}"
    g_log_title "Alertes vers Google Drive"
    g_log_info "Activer l'envoi des alertes vers Google Drive (Y/N)."
    while true; do
        echo ""
        printf '         \e[34m%*s\e[0m : ' 12 "Drive" >&2
        IFS= read -r choice || g_log_error "Entrée interrompue"
        case "${choice}" in
            Y|y)
                : "${G_RCLONE_REMOTE:=gdrive}"
                : "${G_RCLONE_PATH:=liltress-alerts}"
                w_prompt G_RCLONE_REMOTE \
                    "Distant" \
                    "gdrive" \
                    "${G_RCLONE_REMOTE}" \
                    remote \
                    "Lettres, chiffres ou tiret, de 1 à 32 caractères."
                w_prompt G_RCLONE_PATH \
                    "Dossier" \
                    "liltress-alerts" \
                    "${G_RCLONE_PATH}" \
                    drive_path \
                    "Dossier distant, sans .. et sans chemin local."
                if ! command -v rclone >/dev/null 2>&1; then
                    g_log_info "Installation de rclone."
                    g_run_silent_apt install --no-install-recommends -y rclone
                fi
                config="${base}/cron/rclone.conf"
                mkdir -p "${base}/cron"
                rm -f "${config}"
                old_umask="$(umask)"
                umask 077
                if ! RCLONE_CONFIG="${config}" rclone config create "${G_RCLONE_REMOTE}" drive; then
                    umask "${old_umask}"
                    rm -f "${config}"
                    g_log_warn "La configuration rclone a été refusée."
                    g_log_info "Retour au choix Google Drive."
                    continue
                fi
                umask "${old_umask}"
                if [[ ! -f "${config}" ]]; then
                    g_log_warn "La configuration rclone a été refusée."
                    g_log_info "Retour au choix Google Drive."
                    continue
                fi
                chmod 600 "${config}"
                if g_check_drive_probe "${G_RCLONE_REMOTE}" "${G_RCLONE_PATH}" "${config}"; then
                    G_RCLONE_ALERTS=1
                    g_log_success "Essai Google Drive accepté."
                    return 0
                fi
                rm -f "${config}"
                g_log_warn "L'essai Google Drive a été refusé."
                g_log_info "Retour au choix Google Drive."
                ;;
            N|n|non)
                w_clear_drive
                g_log_success "Envoi Google Drive coupé."
                return 0
                ;;
            *)
                g_log_warn "Répondez Y ou N."
                ;;
        esac
    done
}

w_ask_drive_alert

g_log_title "Mode test"
g_log_info "1 : pas de retrait. 0 : question en fin d'installation."
g_log_info "Entrée conserve la valeur en cours (1 par défaut)."
w_prompt G_MODE_TEST \
    "Mode test" \
    "1" \
    "${G_MODE_TEST:-1}" \
    bool01 \
    "Indiquez 0 ou 1."

g_log_info "Enregistrement de la configuration"
mkdir -p "${DIR_SCRIPT}/config"
w_write_global_config "${DIR_SCRIPT}/config/global.conf"
w_write_secret_config "${DIR_SCRIPT}/config/secrets.conf"

if ! w_require_prepared_config "${DIR_SCRIPT}"; then
    g_log_error "Les fichiers écrits ne passent pas le contrôle."
fi

g_log_success "Configuration enregistrée"
exec bash "${DIR_SCRIPT}/scripts/run.sh"
echo ""
