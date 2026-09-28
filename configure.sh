#!/usr/bin/env bash
# =============================================================================
# configure.sh — écrit global.conf et secrets.conf
# =============================================================================
# À lancer avant run.sh. run.sh ne pose aucune question : si ces deux
# fichiers manquent ou ne passent pas le contrôle, il s'arrête.
#
#   bash configure.sh           pose les questions et écrit les fichiers
#   bash configure.sh --check   contrôle les fichiers, code 0 si conformes
#
# Deux secrets : le jeton Ubuntu Pro, et le mot de passe d'application
# Gmail utilisé par Postfix pour envoyer les alertes.
# Le jeton se copie depuis https://ubuntu.com/pro/dashboard
# Le mot de passe d'application se crée sur https://myaccount.google.com/apppasswords
# =============================================================================

set -euo pipefail

DIR_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR_SCRIPT}/config-check.sh"

usage() {
    cat << 'EOF'
Usage :
  bash configure.sh           écrit global.conf et secrets.conf
  bash configure.sh --check   vérifie les deux fichiers, code 0 si conformes

Cette version exige une adresse Gmail (@gmail.com ou @googlemail.com).
Le jeton Ubuntu Pro se trouve sur https://ubuntu.com/pro/dashboard
Le mot de passe SMTP est un mot de passe d'application Gmail :
  https://myaccount.google.com/apppasswords
Entrée conserve une valeur déjà enregistrée, sans réafficher un secret.
Les deux saisies d'un secret doivent être identiques.

Ensuite :
  bash configure.sh --check
  sudo bash run.sh
EOF
}

# __kind : pro_token | gmail | secret | smtp
# gmail : adresse @gmail.com ou @googlemail.com, obligatoire dans cette version.
# Un secret est confirmé deux fois. Entrée reprend la valeur déjà connue.
hfu_prompt() {
    local __var="$1" __label="$2" __example="$3" __default="$4" __kind="$5"
    local value="" confirm="" attempt current=""
    current="${!__var:-}"
    [[ -n "${current}" ]] && __default="${current}"
    for attempt in 1 2 3; do
        printf '\n   %s\n' "${__label}"
        printf '   exemple : %s\n' "${__example}"
        if [[ "${__kind}" == "pro_token" || "${__kind}" == "secret" ]]; then
            if [[ -n "${__default}" ]]; then
                printf '   ➤ (déjà défini — Entrée pour conserver) : '
            else
                printf '   ➤ : '
            fi
            IFS= read -r -s value || { printf 'entrée interrompue\n' >&2; exit 1; }
            printf '\n'
            value="${value// /}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
            else
                printf '   ➤ confirmation : '
                IFS= read -r -s confirm || { printf 'entrée interrompue\n' >&2; exit 1; }
                printf '\n'
                confirm="${confirm// /}"
                if [[ "${value}" != "${confirm}" ]]; then
                    printf '   les deux saisies diffèrent.\n'
                    continue
                fi
            fi
        else
            if [[ -n "${__default}" ]]; then
                printf '   ➤ [%s] : ' "${__default}"
            else
                printf '   ➤ : '
            fi
            IFS= read -r value || { printf 'entrée interrompue\n' >&2; exit 1; }
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
        printf '   format refusé.\n'
    done
    printf 'ERREUR: %s — trop de tentatives. exemple : %s\n' "${__label}" "${__example}" >&2
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
    if hfu_require_prepared_config "${DIR_SCRIPT}"; then
        printf 'Configuration conforme (global.conf + secrets.conf).\n'
        exit 0
    fi
    exit 1
fi

if [[ -n "${1:-}" || $# -gt 0 ]]; then
    usage >&2
    exit 2
fi

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

printf '\nPréparation de global.conf et secrets.conf\n'
printf 'Le jeton active Ubuntu Pro : mises à jour de sécurité ESM et Livepatch.\n'
printf 'Postfix envoie les alertes des contrôles (AIDE, ClamAV, etc.) vers Gmail.\n'
printf 'Aucun mot de passe du compte Ubuntu n’est demandé.\n'

hfu_prompt UBUNTU_PRO_TOKEN "Jeton Ubuntu Pro" "le jeton du tableau de bord ubuntu.com/pro" "" pro_token
hfu_prompt POSTFIX_MAIL_ADDRESS "Adresse Gmail qui envoie les alertes (obligatoire)" "prenom.nom@gmail.com" "" gmail
hfu_prompt POSTFIX_MAIL_PASS "Mot de passe d'application Gmail (16 caractères, sans espaces)" "abcdefghijklmnop" "" secret
hfu_prompt POSTFIX_MAIL_SMTP "Serveur SMTP Gmail" "[smtp.gmail.com]:587" "[smtp.gmail.com]:587" smtp
hfu_prompt WATCHDOG_MAIL "Adresse Gmail qui reçoit les alertes (obligatoire)" "alertes@gmail.com" "${POSTFIX_MAIL_ADDRESS}" gmail

printf '\nÉcrire global.conf et secrets.conf dans %s ? [o/N] ' "${DIR_SCRIPT}"
IFS= read -r confirm || { printf 'entrée interrompue\n' >&2; exit 1; }
if [[ "${confirm}" != "o" && "${confirm}" != "O" && "${confirm}" != "oui" ]]; then
    printf 'ERREUR: écriture annulée. Les fichiers n’ont pas été modifiés.\n' >&2
    exit 1
fi

hfu_write_global_conf "${DIR_SCRIPT}/global.conf"
hfu_write_secrets_conf "${DIR_SCRIPT}/secrets.conf"

if ! hfu_require_prepared_config "${DIR_SCRIPT}"; then
    printf 'ERREUR: les fichiers écrits ne passent pas le contrôle.\n' >&2
    exit 1
fi

printf '\nFichiers prêts.\n'
printf '  global.conf   (HF_PREPARED=1)\n'
printf '  secrets.conf  (chmod 600, HF_SECRETS_PREPARED=1)\n'
printf 'Suite : sudo bash %s/run.sh\n' "${DIR_SCRIPT}"
