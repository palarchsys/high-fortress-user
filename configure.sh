#!/usr/bin/env bash
# =============================================================================
# Fichier    : configure.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   configure.sh — écrit global.conf et secrets.conf
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

# Affiche un encadré d'explication avant une question.
# $1 titre, le reste du texte est lu sur l'entrée standard.
hfu_lesson() {
    local title="$1"
    printf '\n────────────────────────────────────────────────────────────────\n'
    printf ' %s\n' "${title}"
    printf '────────────────────────────────────────────────────────────────\n'
    cat
    printf '\n'
}

# __kind : pro_token | gmail | secret | smtp
# Un secret est masqué et confirmé deux fois. Entrée reprend la valeur déjà connue.
# $6 : phrase affichée quand le format est refusé, pour dire comment corriger.
hfu_prompt() {
    local __var="$1" __label="$2" __example="$3" __default="$4" __kind="$5" __hint="$6"
    local value="" confirm="" attempt current=""
    current="${!__var:-}"
    [[ -n "${current}" ]] && __default="${current}"
    for attempt in 1 2 3; do
        printf '   %s\n' "${__label}"
        printf '   Exemple : %s\n' "${__example}"
        if [[ "${__kind}" == "pro_token" || "${__kind}" == "secret" ]]; then
            printf '   La saisie reste invisible.\n'
            if [[ -n "${__default}" ]]; then
                printf '   Une valeur est déjà enregistrée. Entrée la conserve sans la montrer.\n'
                printf '   ➤ '
            else
                printf '   ➤ '
            fi
            IFS= read -r -s value || { printf 'entrée interrompue\n' >&2; exit 1; }
            printf '\n'
            # Google affiche le mot de passe d'application par groupes de 4.
            value="${value// /}"
            if [[ -z "${value}" && -n "${__default}" ]]; then
                value="${__default}"
                printf '   Valeur déjà enregistrée conservée.\n'
            else
                printf '   Retapez la même valeur pour confirmer.\n'
                printf '   ➤ '
                IFS= read -r -s confirm || { printf 'entrée interrompue\n' >&2; exit 1; }
                printf '\n'
                confirm="${confirm// /}"
                if [[ "${value}" != "${confirm}" ]]; then
                    printf '   Les deux saisies sont différentes. Recommencez cette question.\n\n'
                    continue
                fi
            fi
        else
            if [[ -n "${__default}" ]]; then
                printf '   Entrée conserve la valeur entre crochets.\n'
                printf '   ➤ [%s] ' "${__default}"
            else
                printf '   ➤ '
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
            printf '   Enregistré pour cette étape.\n'
            return 0
        fi
        printf '   Cette réponse ne convient pas. %s\n' "${__hint}"
        printf '   Tentative %s sur 3.\n\n' "${attempt}"
    done
    printf 'ERREUR: %s — trois essais sans réponse acceptée.\n' "${__label}" >&2
    printf 'Exemple attendu : %s\n' "${__example}" >&2
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

# curl | sudo bash a déjà lu le script sur l'entrée standard.
# Les questions suivantes arrivent sur le terminal.
if [[ ! -t 0 ]]; then
    if [[ ! -r /dev/tty ]]; then
        printf 'Pas de terminal pour les questions. Lancez : sudo bash %s/configure.sh\n' "${DIR_SCRIPT}" >&2
        exit 1
    fi
    exec </dev/tty
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

printf '\n════════════════════════════════════════════════════════════════\n'
printf ' Configuration du poste — 5 questions\n'
printf '════════════════════════════════════════════════════════════════\n'
printf '\n'
printf 'Rien n’est écrit sur le disque tant que vous n’avez pas répondu « o »\n'
printf 'à la dernière question. Le mot de passe de votre compte Ubuntu\n'
printf 'n’est jamais demandé.\n'
printf '\n'
printf 'Préparez deux pages dans le navigateur :\n'
printf '  1. https://ubuntu.com/pro/dashboard\n'
printf '     Créez un compte Ubuntu gratuit si besoin, puis copiez le jeton.\n'
printf '  2. https://myaccount.google.com/apppasswords\n'
printf '     Cette version n’accepte qu’une adresse Gmail. Le mot de passe\n'
printf '     habituel de Gmail est refusé : il faut un mot de passe d’application.\n'
printf '     La validation en deux étapes doit être activée avant cette page :\n'
printf '     https://myaccount.google.com/signinoptions/two-step-verification\n'

hfu_lesson 'Question 1 sur 5 — Jeton Ubuntu Pro' << 'EOF'
À quoi il sert.
  Il rattache cet ordinateur à Ubuntu Pro. Le poste reçoit alors les
  correctifs de sécurité étendus (ESM) et certains correctifs du noyau
  sans redémarrage (Livepatch).

Où le copier.
  1. Ouvrez https://ubuntu.com/pro/dashboard
  2. Connectez-vous, ou créez un compte Ubuntu.
  3. Le jeton est affiché sur le tableau de bord. Copiez-le.
  4. Collez-le ici. Lettres et chiffres seulement, sans espace.

Collez le jeton du tableau de bord. Le mot de passe du compte Ubuntu
et le mot de passe Gmail du navigateur ne se saisissent pas ici.
EOF
hfu_prompt UBUNTU_PRO_TOKEN \
    "Collez le jeton Ubuntu Pro" \
    "C1abcdefghij1234567890" \
    "" \
    pro_token \
    "Utilisez uniquement des lettres et des chiffres, entre 6 et 100, sans espace ni tiret."

hfu_lesson 'Question 2 sur 5 — Adresse Gmail qui envoie' << 'EOF'
À quoi elle sert.
  Les contrôles du poste (fichiers modifiés, antivirus, etc.) envoient
  un e-mail quand quelque chose mérite votre attention. Cette adresse
  est l’expéditeur : Gmail doit la reconnaître comme la vôtre.

Ce qu’il faut écrire.
  L’adresse complète, par exemple prenom.nom@gmail.com.
  @gmail.com et @googlemail.com sont acceptés. Outlook, Orange, ou une
  adresse d’entreprise sont refusés dans cette version.
EOF
hfu_prompt POSTFIX_MAIL_ADDRESS \
    "Adresse Gmail qui envoie les alertes" \
    "prenom.nom@gmail.com" \
    "" \
    gmail \
    "L’adresse doit se terminer par @gmail.com ou @googlemail.com."

hfu_lesson 'Question 3 sur 5 — Mot de passe d’application Gmail' << 'EOF'
À quoi il sert.
  Gmail refuse le mot de passe avec lequel vous ouvrez la boîte dans
  le navigateur. Il fournit à la place un mot de passe réservé à cette
  application : 16 lettres.

Comment l’obtenir.
  1. Activez la validation en deux étapes :
     https://myaccount.google.com/signinoptions/two-step-verification
  2. Ouvrez https://myaccount.google.com/apppasswords
  3. Nommez l’application « High-Fortress User », puis créez le mot de passe.
  4. Google l’affiche en quatre groupes. Vous pouvez le coller avec
     les espaces : ils sont retirés ici.

Guide Google : https://support.google.com/accounts/answer/185833
EOF
hfu_prompt POSTFIX_MAIL_PASS \
    "Mot de passe d’application Gmail" \
    "abcdefghijklmnop" \
    "" \
    secret \
    "Il faut au moins 16 caractères, sans espace. Copiez les 16 lettres affichées par Google."

hfu_lesson 'Question 4 sur 5 — Serveur d’envoi' << 'EOF'
À quoi il sert.
  C’est l’adresse du serveur de Gmail qui accepte l’e-mail.

Dans cette version une seule valeur est acceptée :
  [smtp.gmail.com]:587

Les crochets et le :587 font partie de la réponse. Appuyez sur Entrée
pour garder la valeur proposée.
EOF
hfu_prompt POSTFIX_MAIL_SMTP \
    "Serveur SMTP Gmail" \
    "[smtp.gmail.com]:587" \
    "[smtp.gmail.com]:587" \
    smtp \
    "Laissez exactement [smtp.gmail.com]:587, ou appuyez sur Entrée."

hfu_lesson 'Question 5 sur 5 — Adresse Gmail qui reçoit' << 'EOF'
À quoi elle sert.
  C’est la boîte dans laquelle vous lirez les alertes et l’e-mail
  de test envoyé à la fin de l’installation.

Elle doit aussi être une adresse Gmail. Ce peut être la même que
  l’adresse qui envoie. Dans ce cas, appuyez sur Entrée.
EOF
hfu_prompt WATCHDOG_MAIL \
    "Adresse Gmail qui reçoit les alertes" \
    "alertes@gmail.com" \
    "${POSTFIX_MAIL_ADDRESS}" \
    gmail \
    "L’adresse doit se terminer par @gmail.com ou @googlemail.com. Entrée reprend l’adresse qui envoie."

hfu_lesson 'Écriture des fichiers' << EOF
Deux fichiers vont être créés dans ${DIR_SCRIPT} :

  global.conf    les réglages du poste, sans secret
  secrets.conf   le jeton et le courrier, lisibles seulement par vous
                 si vous lancez cette commande, ou par root ensuite

Répondez o pour écrire. Toute autre réponse annule et laisse les
fichiers déjà présents tels quels.
EOF
printf 'Écrire ces fichiers ? [o/N] '
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
