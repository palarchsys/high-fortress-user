#!/usr/bin/env bash
# =============================================================================
# Fichier    : configure.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   configure.sh — écrit global.conf et secrets.conf, puis lance run.sh
# =============================================================================

#   bash configure.sh           cinq questions, puis l'installation
#   bash configure.sh --check   contrôle les fichiers, code 0 si conformes
#
# Jeton : https://ubuntu.com/pro/dashboard
# Mot de passe d'application : https://myaccount.google.com/apppasswords
# =============================================================================

set -euo pipefail

DIR_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/config-check.sh"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/lib.sh"

usage() {
    cat << 'EOF'
Usage :
  sudo bash configure.sh           cinq questions, puis l'installation
  bash configure.sh --check        contrôle les fichiers, code 0 si conformes

Adresse Gmail seulement. Entrée conserve une valeur déjà enregistrée.
Un secret s'affiche en astérisques, puis une seconde ligne demande la confirmation.
EOF
}

# Affiche une étoile par caractère. Retour arrière efface une étoile.
# Entrée termine. Le texte réel reste dans la variable.
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

# Libellé en bleu, deux-points alignés avec la ligne Confirmation.
hfu_secret_line() {
    local label="$1" dest="$2" width="$3"
    printf '         \e[34m%*s\e[0m : ' "${width}" "${label}" >&2
    hfu_read_stars "${dest}"
}

# __kind : pro_token | gmail | secret | smtp
# Un secret s'affiche en astérisques et se confirme sur la ligne suivante.
# Entrée vide reprend la valeur déjà connue, sans la réafficher.
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
            if [[ -n "${__default}" ]]; then
                printf '   \e[34m➤\e[0m [%s] ' "${__default}" >&2
            else
                printf '   \e[34m➤\e[0m ' >&2
            fi
            IFS= read -r value || error "Entrée interrompue"
            [[ -z "${value}" ]] && value="${__default}"
        fi
        local ok=0
        case "${__kind}" in
            pro_token) hfu_is_pro_token "${value}" && ok=1 ;;
            email) hfu_is_email "${value}" && ok=1 ;;
            gmail) hfu_is_gmail "${value}" && ok=1 ;;
            secret) hfu_is_secret "${value}" && ok=1 ;;
            smtp) hfu_is_smtp "${value}" && ok=1 ;;
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

# curl | sudo bash a déjà lu le script sur l'entrée standard.
if [[ ! -t 0 ]]; then
    if [[ ! -r /dev/tty ]]; then
        error "Pas de terminal pour les questions. Lancez : sudo bash ${DIR_SCRIPT}/configure.sh"
    fi
    exec </dev/tty
fi

require_root
clear

hfu_config_set_builtin_defaults

# Relit un fichier déjà écrit pour proposer ses valeurs.
# DIR_INSTALL_PATH est retiré le temps du chargement : sinon global.conf
# tenterait de lire secrets.conf avant que ce script ne l'ait demandé.
_saved_dir_set=0
_saved_dir=""
if [[ -n "${DIR_INSTALL_PATH+x}" ]]; then
    _saved_dir_set=1
    _saved_dir="${DIR_INSTALL_PATH}"
    unset DIR_INSTALL_PATH || true
fi
if [[ -f "${DIR_SCRIPT}/global.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/global.conf"
    set -u
fi
if [[ "${_saved_dir_set}" == "1" ]]; then
    DIR_INSTALL_PATH="${_saved_dir}"
fi
unset _saved_dir _saved_dir_set
if [[ -f "${DIR_SCRIPT}/secrets.conf" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${DIR_SCRIPT}/secrets.conf"
    set -u
fi

violet "═════════════════════════════════════════════════════════════════════════════════"
violet " High-Fortress User — configuration                                               "
violet "═════════════════════════════════════════════════════════════════════════════════"

title "Jeton et e-mail"
info "Cinq réponses. Adresses Gmail seulement."
info "Jeton : https://ubuntu.com/pro/dashboard"
info "Mot de passe d'application : https://myaccount.google.com/apppasswords"

title "1/5 — Jeton Ubuntu Pro"
info "Lettres et chiffres, sans espace."
hfu_prompt UBUNTU_PRO_TOKEN \
    "Jeton Ubuntu Pro" \
    "C1abcdefghij1234567890" \
    "" \
    pro_token \
    "Lettres et chiffres seulement, entre 6 et 100, sans espace."

title "2/5 — Adresse Gmail qui envoie"
info "Entrée garde la valeur proposée."
hfu_prompt POSTFIX_MAIL_ADDRESS \
    "Adresse Gmail qui envoie" \
    "prenom.nom@gmail.com" \
    "" \
    gmail \
    "L'adresse doit se terminer par @gmail.com ou @googlemail.com."

title "3/5 — Mot de passe d'application"
info "16 lettres. Les espaces sont retirés."
hfu_prompt POSTFIX_MAIL_PASS \
    "Mot de passe d'application" \
    "abcdefghijklmnop" \
    "" \
    secret \
    "Au moins 16 caractères, sans espace."

title "4/5 — Serveur SMTP"
info "Entrée garde la valeur proposée."
hfu_prompt POSTFIX_MAIL_SMTP \
    "Serveur SMTP" \
    "[smtp.gmail.com]:587" \
    "[smtp.gmail.com]:587" \
    smtp \
    "Laissez [smtp.gmail.com]:587."

title "5/5 — Adresse Gmail qui reçoit"
info "Entrée garde la valeur proposée."
hfu_prompt WATCHDOG_MAIL \
    "Adresse Gmail qui reçoit" \
    "alertes@gmail.com" \
    "${POSTFIX_MAIL_ADDRESS}" \
    gmail \
    "L'adresse doit se terminer par @gmail.com ou @googlemail.com."

hfu_write_global_conf "${DIR_SCRIPT}/global.conf"
hfu_write_secrets_conf "${DIR_SCRIPT}/secrets.conf"

if ! hfu_require_prepared_config "${DIR_SCRIPT}"; then
    error "Les fichiers écrits ne passent pas le contrôle."
fi

success "Configuration enregistrée"
exec bash "${DIR_SCRIPT}/run.sh"
