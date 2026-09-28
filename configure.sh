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
# La seule donnée secrète est le jeton Ubuntu Pro. Il active les mises à
# jour de sécurité étendues (ESM) et le correctif de noyau Livepatch.
# Le jeton se copie depuis https://ubuntu.com/pro/dashboard
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

Le jeton Ubuntu Pro se trouve sur https://ubuntu.com/pro/dashboard
Entrée conserve un jeton déjà enregistré, sans le réafficher.
Les deux saisies du jeton doivent être identiques.

Ensuite :
  bash configure.sh --check
  sudo bash run.sh
EOF
}

# kind = pro_token : saisie masquée, confirmée deux fois.
# Une valeur déjà présente est conservée si l'utilisateur appuie sur Entrée.
hfu_prompt_token() {
    local value="" confirm="" attempt
    for attempt in 1 2 3; do
        printf '\n   Jeton Ubuntu Pro\n'
        printf '   exemple : le jeton affiché sur https://ubuntu.com/pro/dashboard\n'
        if [[ -n "${UBUNTU_PRO_TOKEN:-}" ]]; then
            printf '   ➤ (déjà défini — Entrée pour conserver) : '
        else
            printf '   ➤ : '
        fi
        IFS= read -r -s value || { printf 'entrée interrompue\n' >&2; exit 1; }
        printf '\n'
        if [[ -z "${value}" && -n "${UBUNTU_PRO_TOKEN:-}" ]]; then
            value="${UBUNTU_PRO_TOKEN}"
        else
            printf '   ➤ confirmation : '
            IFS= read -r -s confirm || { printf 'entrée interrompue\n' >&2; exit 1; }
            printf '\n'
            if [[ "${value}" != "${confirm}" ]]; then
                printf '   les deux saisies diffèrent.\n'
                continue
            fi
        fi
        if hfu_is_pro_token "${value}"; then
            UBUNTU_PRO_TOKEN="${value}"
            return 0
        fi
        printf '   format refusé : lettres et chiffres, 6 à 100 caractères.\n'
    done
    printf 'ERREUR: jeton Ubuntu Pro — trop de tentatives.\n' >&2
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
printf 'Aucun mot de passe du poste n’est demandé.\n'

hfu_prompt_token

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
