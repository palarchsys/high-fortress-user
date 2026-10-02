#!/usr/bin/env bash
# Validateurs de format partagés. Les schémas produit restent dans config-check.sh.
# hf_is_secret (serveur, charset long) et hfu_is_pro_token (poste) ne sont pas ici :
# ils n'ont pas la même règle.

hf_is_email() {
    [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]
}

hf_is_port() {
    local min="$2" max="$3"
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    (( 10#$1 >= min && 10#$1 <= max )) || return 1
    return 0
}

# hôte:port, sans crochets. Exemple : smtp-mail.outlook.com:587
hf_is_smtp() {
    local host port
    [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?:[0-9]+$ ]] || return 1
    host="${1%:*}"
    port="${1##*:}"
    [[ "${host}" != *..* && "${host}" != .* && "${host}" != *. ]] || return 1
    hf_is_port "${port}" 1 65535
}

# Chemin absolu sans « .. » ni espace.
hf_is_abs_path() {
    [[ "$1" =~ ^/[A-Za-z0-9._/-]+$ && "$1" != *..* ]]
}

# Mot de passe d'application : assez long, sans espace ni caractère
# qui casserait une ligne CLE="valeur".
hf_is_app_password() {
    local value="$1" i c tick=$'\x60'
    [[ "${#value}" -ge 8 && "${#value}" -le 128 ]] || return 1
    for ((i = 0; i < ${#value}; i++)); do
        c="${value:i:1}"
        case "${c}" in
            [[:space:]] | '"' | "'" | '$' | '\' | "${tick}")
                return 1
                ;;
        esac
    done
    return 0
}

hfu_is_email() { hf_is_email "$@"; }
hfu_is_port() { hf_is_port "$@"; }
hfu_is_smtp() { hf_is_smtp "$@"; }
hfu_is_abs_path() { hf_is_abs_path "$@"; }
# Même règle que le mot de passe d'application. Le nom poste est conservé.
hfu_is_secret() { hf_is_app_password "$@"; }
