#!/usr/bin/env bash
# =============================================================================
# core/lib.sh — fonctions des deux installeurs
# =============================================================================
# Sourcé par run.sh et par chaque étape. set -euo pipefail s'applique
# au script appelant. Les noms historiques sont conservés.
#
# Le poste est SERVER_TYPE=WORKSTATION ou PROJECT_SLUG=high-fortress-user.
# Les collecteurs de l'autre produit s'arrêtent tout de suite : log.sh
# appelle les deux. assert_no_password_mutation n'est appelée par aucun
# script du serveur. hf_chpasswd reste dans server/system/configure.sh.
# =============================================================================

set -euo pipefail

if [[ -z "${HF_PRODUCT_ROOT:-}" ]]; then
    if [[ -n "${DIR_INSTALL_PATH:-}" ]]; then
        HF_PRODUCT_ROOT="${DIR_INSTALL_PATH}"
    else
        HF_PRODUCT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
    fi
fi
export HF_PRODUCT_ROOT

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
hf_source_core log.sh
hf_source_core exec.sh
hf_source_core fs.sh

# Vrai seulement pour le poste. Lit global.conf si les variables
# ne sont pas encore chargées, pour ne pas lancer le collecteur serveur.
hf_is_workstation() {
    [[ "${SERVER_TYPE:-}" == "WORKSTATION" || "${PROJECT_SLUG:-}" == "high-fortress-user" ]] && return 0
    [[ -n "${HF_PRODUCT_ROOT:-}" && -f "${HF_PRODUCT_ROOT}/global.conf" ]] || return 1
    grep -qE '^(SERVER_TYPE="WORKSTATION"|PROJECT_SLUG="high-fortress-user")$' "${HF_PRODUCT_ROOT}/global.conf"
}

# Échoue si un bind TCP hôte occupe déjà le port (Docker userland-proxy / 127.0.0.1).
assert_localhost_port_free() {
    local port="$1"
    local line
    line="$(ss -ltnp "sport = :${port}" 2>/dev/null | awk 'NR>1')"
    if [[ -n "${line}" ]]; then
        error "Port TCP ${port} déjà occupé — bind Docker 127.0.0.1:${port} impossible : ${line}"
    fi
}

set_main_hostname() {
    case "${SERVER_TYPE:-}" in
        MATRIX)    MAIN_HOSTNAME="${HOSTNAME_MATRIX}" ;;
        LIVEKIT)   MAIN_HOSTNAME="${HOSTNAME_LIVEKIT}" ;;
        WIREGUARD) MAIN_HOSTNAME="${HOSTNAME_WIREGUARD}" ;;
        *) error "SERVER_TYPE invalide : '${SERVER_TYPE:-}'" ;;
    esac
    export MAIN_HOSTNAME
}

get_matrix_admin_access_token() {
    local url="${MATRIX_URL:-http://127.0.0.1:8008}"
    local user="${MATRIX_ADMIN_USER}"
    local pass="${MATRIX_ADMIN_PASSWORD}"

    if [ -z "$user" ] || [ -z "$pass" ]; then
        error "MATRIX_ADMIN_USER ou MATRIX_ADMIN_PASSWORD vide."
    fi

    info "Connexion à $url avec $user ..."

    local payload
    payload=$(jq -n --arg user "$user" --arg pass "$pass" \
        '{type: "m.login.password", user: $user, password: $pass}')

    local response
    response=$(curl -s -X POST "${url}/_matrix/client/v3/login" \
        -H "Content-Type: application/json" \
        -d "${payload}")

    MATRIX_ADMIN_ACCESS_TOKEN=$(echo "$response" | jq -r '.access_token // empty')

    if [ -z "$MATRIX_ADMIN_ACCESS_TOKEN" ]; then
        info "$response" | jq . 2>/dev/null || echo "$response"
        error "Échec de récupération du token !"
    fi

    success "Token récupéré avec succès !"
}


# Snapshot propre au serveur (docker, nginx, pare-feu applicatif).
# Le tronc commun est dans core/log.sh. On ne retire aucun collecteur.
hf_collect_product_logs() {
    local snap="$1"
    if hf_is_workstation; then
        return 0
    fi
    nginx -t > "${snap}/nginx-t.txt" 2>&1 || true
    fail2ban-client status > "${snap}/fail2ban-status.txt" 2>&1 || true
    cscli collections list > "${snap}/crowdsec-collections.txt" 2>&1 || true
    cscli bouncers list > "${snap}/crowdsec-bouncers.txt" 2>&1 || true

    if command -v docker >/dev/null 2>&1; then
        docker ps -a > "${snap}/docker-ps.txt" 2>&1 || true
        docker network ls > "${snap}/docker-networks.txt" 2>&1 || true
        docker images > "${snap}/docker-images.txt" 2>&1 || true
        mkdir -p "${snap}/docker-logs"
        local cid cname
        for cid in $(docker ps -aq 2>/dev/null); do
            cname=$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##')
            docker logs --tail 400 "$cid" > "${snap}/docker-logs/${cname:-$cid}.log" 2>&1 || true
        done
    fi

    mkdir -p "${snap}/etc"
    local cfg
    for cfg in /etc/nginx/nginx.conf /etc/ssh/sshd_config /etc/fail2ban/jail.local \
               /etc/sysctl.d/90-secure_ips.conf /etc/systemd/journald.conf.d/persistent.conf; do
        if [[ -r "$cfg" ]]; then
            cp -a "$cfg" "${snap}/etc/$(echo "$cfg" | tr '/' '_')" 2>/dev/null || true
        fi
    done
    if [[ -d /etc/nginx/sites-enabled ]]; then
        mkdir -p "${snap}/etc/nginx-sites-enabled"
        cp -a /etc/nginx/sites-enabled/. "${snap}/etc/nginx-sites-enabled/" 2>/dev/null || true
    fi

    # Compose générés (pas les .env secrets)
    if [[ -n "${DOCKER_BASE_DIR:-}" && -d "${DOCKER_BASE_DIR}" ]]; then
        mkdir -p "${snap}/docker-compose"
        find "${DOCKER_BASE_DIR}" -name 'docker-compose.yml' -exec cp -a {} "${snap}/docker-compose/" \; 2>/dev/null || true
        find "${snap}/docker-compose" -name '*.env' -delete 2>/dev/null || true
    fi
}

# Le paquet Ubuntu npm n'est pas installé (il entraîne gcc). S'il est quand
# même présent, ou si corepack l'est, on les réserve au compte SSH.
# Le mode 500 et dpkg-statoverride survivent à apt upgrade ; run.sh rappelle
# la fonction après l'upgrade. Node.js n'est pas modifié.
# Le répertoire du code est inclus : sinon « node …/npm-cli.js » contourne
# le lanceur.

hf_statoverride_user_exec() {
    local path="$1"
    local out=""
    [[ -e "${path}" && ! -L "${path}" ]] || return 0
    if dpkg-statoverride --list "${path}" >/dev/null 2>&1; then
        out="$(dpkg-statoverride --remove "${path}" 2>&1)" || error "dpkg-statoverride --remove ${path} : ${out}"
    fi
    out="$(dpkg-statoverride --update --add "${MAIN_USER}" "${MAIN_GROUP}" 500 "${path}" 2>&1)" \
        || error "dpkg-statoverride ${path} : ${out}"
}

hf_lock_npm_to_main_user() {
    [[ "${SERVER_TYPE:-}" == "MATRIX" ]] || return 0
    command -v dpkg-statoverride >/dev/null 2>&1 || return 0
    local have_npm=0 have_corepack=0
    dpkg -s npm >/dev/null 2>&1 && have_npm=1
    dpkg -s node-corepack >/dev/null 2>&1 && have_corepack=1
    [[ "${have_npm}" -eq 1 || "${have_corepack}" -eq 1 ]] || return 0
    [[ -n "${MAIN_USER:-}" && -n "${MAIN_GROUP:-}" ]] || error "npm : MAIN_USER ou MAIN_GROUP vide"
    getent passwd "${MAIN_USER}" >/dev/null || error "npm : compte ${MAIN_USER} introuvable"
    getent group "${MAIN_GROUP}" >/dev/null || error "npm : groupe ${MAIN_GROUP} introuvable"

    local listed="" real="" root="" locked=0
    while IFS= read -r listed; do
        [[ -n "${listed}" ]] || continue
        case "${listed}" in
            /usr/share/doc/*|/usr/share/man/*|/usr/share/lintian/*) continue ;;
            /usr/bin/node|/usr/bin/nodejs) continue ;;
        esac
        if [[ "${listed}" == /usr/bin/* || "${listed}" == /usr/local/bin/* ]]; then
            if [[ -L "${listed}" ]]; then
                real="$(readlink -f "${listed}" 2>/dev/null || true)"
                case "${real}" in
                    */bin/node|*/bin/nodejs|"") ;;
                    *)
                        if [[ -f "${real}" ]]; then
                            hf_statoverride_user_exec "${real}"
                            locked=1
                        fi
                        ;;
                esac
            elif [[ -f "${listed}" ]]; then
                hf_statoverride_user_exec "${listed}"
                locked=1
            fi
        fi
        if [[ "${listed}" == */npm-cli.js || "${listed}" == */npx-cli.js ]]; then
            real="$(dirname "${listed}")"
            if [[ "$(basename "${real}")" == "bin" ]]; then
                real="$(dirname "${real}")"
            fi
            if [[ -z "${root}" && -d "${real}" ]]; then
                root="${real}"
            fi
        fi
    done < <(if [[ "${have_npm}" -eq 1 ]]; then dpkg -L npm 2>/dev/null || true; fi)

    if [[ -n "${root}" ]]; then
        hf_statoverride_user_exec "${root}"
        locked=1
    fi
    # corepack sait lancer npm. Son arbre est réservé au même compte.
    if [[ "${have_corepack}" -eq 1 && -d /usr/share/nodejs/corepack ]]; then
        hf_statoverride_user_exec /usr/share/nodejs/corepack
        locked=1
    fi
    if [[ -e /usr/bin/corepack || -L /usr/bin/corepack ]]; then
        if [[ -L /usr/bin/corepack ]]; then
            real="$(readlink -f /usr/bin/corepack 2>/dev/null || true)"
        else
            real="/usr/bin/corepack"
        fi
        case "${real}" in
            */bin/node|*/bin/nodejs|"") ;;
            *)
                if [[ -n "${real}" && -f "${real}" ]]; then
                    hf_statoverride_user_exec "${real}"
                    locked=1
                fi
                ;;
        esac
    fi
    if [[ "${have_npm}" -eq 1 && "${locked}" -eq 0 ]]; then
        error "npm est installé, aucun fichier à réserver à ${MAIN_USER}"
    fi
    [[ "${locked}" -eq 1 ]] || return 0
    success "npm réservé à ${MAIN_USER}"
}

# -----------------------------------------------------------------------------
# Deux accès.
# PROD (MODE_TEST=0 et MODE_DEV=0) : https://<nom>, Nginx, Cloudflare.
# TEST ou DEV (l'un des deux à 1) : http://127.0.0.1:<port>.
# global.conf garde les URL https. Cette fonction ne réécrit pas le fichier.
# À appeler après source global.conf, avant envsubst.
# -----------------------------------------------------------------------------

hf_local_browser() {
    [[ "${MODE_TEST:-0}" == "1" || "${MODE_DEV:-0}" == "1" ]]
}

hf_apply_runtime_urls() {
    if hf_local_browser; then
        KEYCLOAK_PUBLIC_BASEURL="http://127.0.0.1:${PORT_KEYCLOAK}"
        MATRIX_PUBLIC_BASEURL="http://127.0.0.1:${PORT_SYNAPSE}"
        ELEMENT_PUBLIC_BASEURL="http://127.0.0.1:${PORT_ELEMENT}"
        HF_PUBLIC_BASE_URL="http://127.0.0.1:${PORT_WEB_UI}"
        HF_API_BASE_URL="http://127.0.0.1:${PORT_WEB_API}"
        HF_CORS_ORIGINS="http://127.0.0.1:${PORT_WEB_UI}"
        HF_LIVEKIT_URL="ws://127.0.0.1:${PORT_LIVEKIT_SFU}"
        HF_JWT_URL="http://127.0.0.1:${PORT_LIVEKIT_JWT}"
        WG_HOST="127.0.0.1"
        HF_WG_UI_URL="http://127.0.0.1:${PORT_WIREGUARD_UI}"
    else
        HF_PUBLIC_BASE_URL="https://${DOMAIN}"
        HF_API_BASE_URL="https://${DOMAIN_WEB_API}"
        HF_CORS_ORIGINS="https://${DOMAIN}"
        HF_LIVEKIT_URL="wss://${DOMAIN_LIVEKIT_SFU}"
        HF_JWT_URL="https://${DOMAIN_LIVEKIT_JWT}"
        WG_HOST="${DOMAIN_WIREGUARD}"
        HF_WG_UI_URL="https://${DOMAIN_WIREGUARD}"
    fi
    export KEYCLOAK_PUBLIC_BASEURL MATRIX_PUBLIC_BASEURL ELEMENT_PUBLIC_BASEURL
    export HF_PUBLIC_BASE_URL HF_API_BASE_URL HF_CORS_ORIGINS
    export HF_LIVEKIT_URL HF_JWT_URL WG_HOST HF_WG_UI_URL
}

# Clés Turnstile publiques « always pass » (Cloudflare). Inutile hors mode test.
mode_test_use_turnstile_keys() {
    [[ "${MODE_TEST:-0}" == "1" ]] || return 0
    TURNSTILE_SITE_KEY="1x00000000000000000000AA"
    TURNSTILE_SECRET_KEY="1x0000000000000000000000000000000AA"
    export TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY
}

# Retire un ancien bloc qui faisait résoudre les noms vers le loopback.
mode_test_strip_hosts() {
    [[ -f /etc/hosts ]] || return 0
    grep -q '# BEGIN high-fortress MODE_TEST' /etc/hosts || return 0
    local tmp
    tmp="$(mktemp)"
    awk '
        $0 == "# BEGIN high-fortress MODE_TEST" { skip = 1; next }
        $0 == "# END high-fortress MODE_TEST" { skip = 0; next }
        skip { next }
        { print }
    ' /etc/hosts > "${tmp}"
    cat "${tmp}" > /etc/hosts
    rm -f "${tmp}"
    success "Noms de domaine retirés de /etc/hosts"
}

# Certificat seulement pour que nginx -t passe : Certbot ne tourne pas.
# Le navigateur n'ouvre pas ces noms.
mode_test_prepare_local() {
    [[ "${MODE_TEST:-0}" == "1" ]] || return 0

    local live="/etc/letsencrypt/live/${DOMAIN}"
    mkdir -p "${live}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout "${live}/privkey.pem" \
        -out "${live}/fullchain.pem" \
        -subj "/CN=${DOMAIN}" >/dev/null 2>&1
    chmod 640 "${live}/privkey.pem"
    chmod 644 "${live}/fullchain.pem"

    mode_test_strip_hosts
    if [[ -f /usr/local/share/ca-certificates/high-fortress-mode-test.crt ]]; then
        rm -f /usr/local/share/ca-certificates/high-fortress-mode-test.crt
        update-ca-certificates >/dev/null || true
        success "Certificat de test retiré du magasin système"
    fi
    success "MODE_TEST : Nginx a un certificat local. Le navigateur utilise http://127.0.0.1"
}

# -----------------------------------------------------------------------------
# Secrets : uniquement secrets.conf, produit par configure.sh.
# L'installateur ne demande rien. Voir hf_require_prepared_config.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Détection workstation
# -----------------------------------------------------------------------------

detect_current_user() {
    local u="${SUDO_USER:-${HFU_USER:-}}"
    if [[ -z "$u" || "$u" == "root" ]]; then
        u="$(awk -F: '$3 >= 1000 && $3 < 65534 && $1 != "nobody" { print $1; exit }' /etc/passwd)"
    fi
    if [[ -z "$u" ]]; then
        error "Impossible de déterminer l'utilisateur courant (SUDO_USER vide, aucun uid≥1000)."
    fi
    CURRENT_USER="$u"
    CURRENT_GROUP="$(id -gn "$CURRENT_USER")"
    CURRENT_HOME="$(getent passwd "$CURRENT_USER" | awk -F: '{print $6}')"
    export CURRENT_USER CURRENT_GROUP CURRENT_HOME
}

detect_os() {
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
    OS_PRETTY="${PRETTY_NAME:-}"
    export OS_ID OS_VERSION_ID OS_PRETTY
    if [[ "${OS_ID}" != "ubuntu" || "${OS_VERSION_ID}" != "26.04" ]]; then
        error "Ubuntu 26.04 requis (installation fraîche). Détecté : ${OS_PRETTY:-inconnu}."
    fi
}

# Vrai pour un compte ouvert par l'installateur Ubuntu.
# Un compte de service peut avoir un uid élevé : libvirt-qemu est en 64055,
# avec le dossier /nonexistent et le shell nologin. Il n'entre pas dans
# la comparaison, sinon son apparition en cours d'installation est un échec.
hfu_is_desktop_account() {
    local uid="$1" home="$2" shell="$3"
    [[ "${uid}" -ge 1000 && "${uid}" -lt 60000 ]] || return 1
    [[ "${home}" == /home/* ]] || return 1
    case "${shell}" in
        */nologin|*/false) return 1 ;;
    esac
    return 0
}

# Empreinte des comptes du bureau.
# Comparée en fin de script : uid, gid, gecos, home, shell, groupes, hash shadow, chage.
write_human_account_table() {
    local dest="$1"
    local name uid gid gecos home shell groups shadow_fp maxdays
    : > "${dest}.tmp"
    while IFS=: read -r name _ uid gid gecos home shell; do
        if ! hfu_is_desktop_account "${uid}" "${home}" "${shell}"; then
            continue
        fi
        groups="$(id -nG "${name}" | tr ' ' '\n' | LC_ALL=C sort | paste -sd, -)"
        shadow_fp="$(awk -F: -v u="${name}" '$1==u { print $2 }' /etc/shadow | sha256sum | awk '{ print $1 }')"
        maxdays="$(LANG=C LC_ALL=C chage -l "${name}" 2>/dev/null | awk -F: '/Maximum/ { gsub(/ /, "", $2); print $2 }')"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${name}" "${uid}" "${gid}" "${gecos}" "${home}" "${shell}" \
            "${groups}" "${shadow_fp}" "${maxdays}" >> "${dest}.tmp"
    done < /etc/passwd
    LC_ALL=C sort -o "${dest}" "${dest}.tmp"
    rm -f "${dest}.tmp"
    chmod 600 "${dest}"
}

HFU_ACCOUNT_SNAPSHOT="/var/lib/high-fortress-user/accounts/human.tsv"

snapshot_human_accounts() {
    mkdir -p /var/lib/high-fortress-user/accounts
    chmod 700 /var/lib/high-fortress-user/accounts
    write_human_account_table "${HFU_ACCOUNT_SNAPSHOT}"
    # Empreinte shadow : uniquement sur la machine, mode 600.
    # Jamais dans la copie du dossier partagé.
    if [[ -n "${HF_LOG_SYS:-}" ]]; then
        mkdir -p "${HF_LOG_SYS}/accounts"
        chmod 700 "${HF_LOG_SYS}/accounts"
        cp -a "${HFU_ACCOUNT_SNAPSHOT}" "${HF_LOG_SYS}/accounts/human.tsv"
        chmod 600 "${HF_LOG_SYS}/accounts/human.tsv"
    fi
    local n
    n="$(wc -l < "${HFU_ACCOUNT_SNAPSHOT}" | tr -d ' ')"
    if [[ "${n}" -lt 1 ]]; then
        error "Aucun compte de bureau sous /home : l'installateur Ubuntu doit avoir créé les utilisateurs."
    fi
    success "Empreinte de ${n} compte(s) humain(s) enregistrée (non modifiés ensuite)"
}

# Retire les groupes libvirt et kvm de la colonne des groupes.
# Le paquet libvirt-daemon-system les ajoute aux membres de sudo :
# uid, home, shell et mot de passe restent comparés tels quels.
hfu_strip_virt_groups() {
    awk -F '\t' 'BEGIN { OFS = "\t" } {
        n = split($7, g, ",")
        out = ""
        for (i = 1; i <= n; i++) {
            if (g[i] != "libvirt" && g[i] != "kvm") {
                out = out (out ? "," : "") g[i]
            }
        }
        $7 = out
        print
    }'
}

# Affiche un diff et retourne 1 si un compte humain a changé.
human_accounts_drift() {
    local current baseline="${HFU_ACCOUNT_SNAPSHOT}" norm_base norm_now
    [[ -f "${baseline}" ]] || {
        echo "snapshot des comptes absent (${baseline})"
        return 1
    }
    current="$(mktemp)"
    norm_base="$(mktemp)"
    norm_now="$(mktemp)"
    write_human_account_table "${current}"
    hfu_strip_virt_groups < "${baseline}" > "${norm_base}"
    hfu_strip_virt_groups < "${current}" > "${norm_now}"
    if cmp -s "${norm_base}" "${norm_now}"; then
        rm -f "${current}" "${norm_base}" "${norm_now}"
        return 0
    fi
    diff -u "${baseline}" "${current}" || true
    rm -f "${current}" "${norm_base}" "${norm_now}"
    return 1
}

detect_ssh_port() {
    local port="22"
    if command -v sshd >/dev/null 2>&1; then
        port="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
        [[ -z "$port" ]] && port="22"
    fi
    SSH_PORT="$port"
    export SSH_PORT
}

virt_present() {
    if command -v virsh >/dev/null 2>&1; then
        return 0
    fi
    if dpkg-query -W -f '${Status}\n' qemu-kvm qemu-system-x86 libvirt-daemon 2>/dev/null | grep -q 'install ok'; then
        return 0
    fi
    if [[ -e /dev/kvm ]]; then
        return 0
    fi
    return 1
}

app_present() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 && return 0
    dpkg-query -W -f '${Status}\n' "$name" 2>/dev/null | grep -q 'install ok' && return 0
    flatpak info "$name" >/dev/null 2>&1 && return 0
    return 1
}

# Refuse toute mutation de mot de passe (garde-fou global).
assert_no_password_mutation() {
    case "$*" in
        *chpasswd*|*passwd\ *|*" usermod -p "*|*chage*)
            error "Garde-fou : tentative de mutation de mot de passe interdite : $*"
            ;;
    esac
}


# Snapshot propre au poste. Pas de jeton Ubuntu Pro dans le fichier.
hfu_collect_product_logs() {
    local snap="$1"
    hf_is_workstation || return 0
    {
        echo "=== unbound ==="
        systemctl status unbound --no-pager -l 2>&1 | head -n 80 || true
        echo "=== resolvectl ==="
        resolvectl status 2>&1 | head -n 120 || true
    } > "${snap}/unbound.txt" 2>&1 || true

    if command -v pro >/dev/null 2>&1; then
        pro status 2>&1 | sed -E 's/[A-Za-z0-9]{20,}/[redacted]/g' > "${snap}/ubuntu-pro.txt" || true
    fi

    local f
    for f in /var/log/aide/aide.log /var/lib/aide/aide.log /opt/high-fortress-user/cron/security_logs; do
        if [[ -f "$f" ]]; then
            tail -n 200 "$f" > "${snap}/$(basename "$f").tail.txt" 2>/dev/null || true
        fi
    done
}

# Vrai si « pro status » indique que la machine est déjà rattachée à Ubuntu Pro.
# Le jeton reste obligatoire dans secrets.conf : ce test sert seulement à
# ne pas rappeler pro attach quand le rattachement est déjà fait.
ubuntu_pro_attached() {
    command -v pro >/dev/null 2>&1 || return 1
    local st
    st="$(pro status --format json 2>/dev/null || true)"
    if [[ -n "$st" ]] && command -v jq >/dev/null 2>&1; then
        echo "$st" | jq -e '.attached == true' >/dev/null 2>&1 && return 0
    fi
    pro status 2>/dev/null | grep -qiE 'This machine is attached|machine is attached to an Ubuntu Pro|est attachée|Attached:[[:space:]]*(yes|true)' && return 0
    return 1
}
