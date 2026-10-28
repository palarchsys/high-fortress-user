#!/usr/bin/env bash
# =============================================================================
# File       : core/lib.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

set -euo pipefail

if [[ -z "${G_PRODUCT_ROOT:-}" ]]; then
    if [[ -n "${G_INSTALL_DIRECTORY:-}" ]]; then
        G_PRODUCT_ROOT="${G_INSTALL_DIRECTORY}"
    else
        G_PRODUCT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
    fi
fi
export G_PRODUCT_ROOT

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
g_source_core log.sh
g_source_core exec.sh
g_source_core fs.sh

g_check_workstation() {
    [[ "${S_SERVER_TYPE:-}" == "WORKSTATION" || "${W_PROJECT_SLUG:-}" == "liltress-workstation" ]] && return 0
    [[ -n "${G_PRODUCT_ROOT:-}" && -f "${G_PRODUCT_ROOT}/config/global.conf" ]] || return 1
    grep -qE '^(S_SERVER_TYPE="WORKSTATION"|W_PROJECT_SLUG="liltress-workstation")$' "${G_PRODUCT_ROOT}/config/global.conf"
}

g_check_localhost_port() {
    local port="$1"
    local line
    line="$(ss -ltnp "sport = :${port}" 2>/dev/null | awk 'NR>1')"
    if [[ -n "${line}" ]]; then
        g_log_error "Port TCP ${port} déjà occupé — bind Docker 127.0.0.1:${port} impossible : ${line}"
    fi
}

g_set_main_hostname() {
    case "${S_SERVER_TYPE:-}" in
        MATRIX)    MAIN_HOSTNAME="${S_HOSTNAME_MATRIX}" ;;
        LIVEKIT)   MAIN_HOSTNAME="${S_HOSTNAME_LIVEKIT}" ;;
        WIREGUARD) MAIN_HOSTNAME="${S_HOSTNAME_WIREGUARD}" ;;
        *) g_log_error "S_SERVER_TYPE invalide : '${S_SERVER_TYPE:-}'" ;;
    esac
    export MAIN_HOSTNAME
}

s_get_matrix_admin_token() {
    local url="${MATRIX_URL:-http://127.0.0.1:8008}"
    local user="${S_MATRIX_ADMIN_USER}"
    local pass="${S_MATRIX_ADMIN_PASSWORD}"

    if [ -z "$user" ] || [ -z "$pass" ]; then
        g_log_error "S_MATRIX_ADMIN_USER ou S_MATRIX_ADMIN_PASSWORD vide."
    fi

    g_log_info "Récupération du jeton Matrix de ${user}"

    local payload
    payload=$(jq -n --arg user "$user" --arg pass "$pass" \
        '{type: "m.login.password", user: $user, password: $pass}')

    local response
    response=$(curl -s -X POST "${url}/_matrix/client/v3/login" \
        -H "Content-Type: application/json" \
        -d "${payload}")

    S_MATRIX_ADMIN_ACCESS_TOKEN=$(echo "$response" | jq -r '.access_token // empty')

    if [ -z "$S_MATRIX_ADMIN_ACCESS_TOKEN" ]; then
        g_log_info "$response" | jq . 2>/dev/null || echo "$response"
        g_log_error "Échec de récupération du token !"
    fi

    g_log_success "Jeton Matrix récupéré"
}

g_collect_product_logs() {
    local snap="$1"
    if g_check_workstation; then
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
            docker logs --tail 2000 "$cid" > "${snap}/docker-logs/${cname:-$cid}.log" 2>&1 || true
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

    if [[ -n "${S_DOCKER_BASE_DIRECTORY:-}" && -d "${S_DOCKER_BASE_DIRECTORY}" ]]; then
        mkdir -p "${snap}/docker-compose"
        find "${S_DOCKER_BASE_DIRECTORY}" -name 'docker-compose.yml' -exec cp -a {} "${snap}/docker-compose/" \; 2>/dev/null || true
        find "${snap}/docker-compose" -name '*.env' -delete 2>/dev/null || true
    fi

    g_copy_unit_journals "${snap}" \
        nginx docker containerd fail2ban crowdsec crowdsec-firewall-bouncer \
        auditd clamav-daemon clamav-freshclam clamonacc postfix ssh redis-server cron apparmor \
        || true
}

g_set_statoverride_user_exec() {
    local path="$1"
    local out=""
    [[ -e "${path}" && ! -L "${path}" ]] || return 0
    if dpkg-statoverride --list "${path}" >/dev/null 2>&1; then
        out="$(dpkg-statoverride --remove "${path}" 2>&1)" || g_log_error "dpkg-statoverride --remove ${path} : ${out}"
    fi
    out="$(dpkg-statoverride --update --add "${S_MAIN_USER}" "${S_MAIN_GROUP}" 500 "${path}" 2>&1)" \
        || g_log_error "dpkg-statoverride ${path} : ${out}"
}

g_lock_npm_to_main_user() {
    [[ "${S_SERVER_TYPE:-}" == "MATRIX" ]] || return 0
    command -v dpkg-statoverride >/dev/null 2>&1 || return 0
    local have_npm=0 have_corepack=0
    dpkg -s npm >/dev/null 2>&1 && have_npm=1
    dpkg -s node-corepack >/dev/null 2>&1 && have_corepack=1
    [[ "${have_npm}" -eq 1 || "${have_corepack}" -eq 1 ]] || return 0
    [[ -n "${S_MAIN_USER:-}" && -n "${S_MAIN_GROUP:-}" ]] || g_log_error "npm : S_MAIN_USER ou S_MAIN_GROUP vide"
    getent passwd "${S_MAIN_USER}" >/dev/null || g_log_error "npm : compte ${S_MAIN_USER} introuvable"
    getent group "${S_MAIN_GROUP}" >/dev/null || g_log_error "npm : groupe ${S_MAIN_GROUP} introuvable"
    g_log_info "Réservation de npm pour ${S_MAIN_USER}"

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
                            g_set_statoverride_user_exec "${real}"
                            locked=1
                        fi
                        ;;
                esac
            elif [[ -f "${listed}" ]]; then
                g_set_statoverride_user_exec "${listed}"
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
        g_set_statoverride_user_exec "${root}"
        locked=1
    fi

    if [[ "${have_corepack}" -eq 1 && -d /usr/share/nodejs/corepack ]]; then
        g_set_statoverride_user_exec /usr/share/nodejs/corepack
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
                    g_set_statoverride_user_exec "${real}"
                    locked=1
                fi
                ;;
        esac
    fi
    if [[ "${have_npm}" -eq 1 && "${locked}" -eq 0 ]]; then
        g_log_error "npm est installé, aucun fichier à réserver à ${S_MAIN_USER}"
    fi
    [[ "${locked}" -eq 1 ]] || return 0
    g_log_success "npm réservé à ${S_MAIN_USER}"
}

g_get_local_browser() {
    [[ "${G_MODE_TEST:-0}" == "1" || "${S_MODE_DEV:-0}" == "1" ]]
}

g_apply_runtime_urls() {
    if g_get_local_browser; then
        S_KEYCLOAK_PUBLIC_BASE_URL="http://127.0.0.1:${S_PORT_KEYCLOAK}"
        S_MATRIX_PUBLIC_BASE_URL="http://127.0.0.1:${S_PORT_SYNAPSE}"
        S_ELEMENT_PUBLIC_BASE_URL="http://127.0.0.1:${S_PORT_ELEMENT}"
        G_PUBLIC_BASE_URL="http://127.0.0.1:${S_PORT_WEB_UI}"
        G_API_BASE_URL="http://127.0.0.1:${S_PORT_WEB_API}"
        G_CORS_ORIGINS="http://127.0.0.1:${S_PORT_WEB_UI}"
        G_LIVEKIT_URL="ws://127.0.0.1:${S_PORT_LIVEKIT_SFU}"
        G_JWT_URL="http://127.0.0.1:${S_PORT_LIVEKIT_JWT}"
        S_WIREGUARD_HOST="127.0.0.1"
        G_WIREGUARD_UI_URL="http://127.0.0.1:${S_PORT_WIREGUARD_UI}"
    else
        G_PUBLIC_BASE_URL="https://${S_DOMAIN}"
        G_API_BASE_URL="https://${S_DOMAIN_WEB_API}"
        G_CORS_ORIGINS="https://${S_DOMAIN}"
        G_LIVEKIT_URL="wss://${S_DOMAIN_LIVEKIT_SFU}"
        G_JWT_URL="https://${S_DOMAIN_LIVEKIT_JWT}"
        S_WIREGUARD_HOST="${S_DOMAIN_WIREGUARD}"
        G_WIREGUARD_UI_URL="https://${S_DOMAIN_WIREGUARD}"
    fi
    export S_KEYCLOAK_PUBLIC_BASE_URL S_MATRIX_PUBLIC_BASE_URL S_ELEMENT_PUBLIC_BASE_URL
    export G_PUBLIC_BASE_URL G_API_BASE_URL G_CORS_ORIGINS
    export G_LIVEKIT_URL G_JWT_URL S_WIREGUARD_HOST G_WIREGUARD_UI_URL
}

g_set_mode_test_turnstile() {
    [[ "${G_MODE_TEST:-0}" == "1" ]] || return 0
    S_TURNSTILE_SITE_KEY="1x00000000000000000000AA"
    S_TURNSTILE_SECRET_KEY="1x0000000000000000000000000000000AA"
    export S_TURNSTILE_SITE_KEY S_TURNSTILE_SECRET_KEY
}

g_strip_mode_test_host() {
    [[ -f /etc/hosts ]] || return 0
    grep -q '# BEGIN liltress G_MODE_TEST' /etc/hosts || return 0
    g_log_info "Retrait des noms de domaine de /etc/hosts"
    local tmp
    tmp="$(mktemp)"
    awk '
        $0 == "# BEGIN liltress G_MODE_TEST" { skip = 1; next }
        $0 == "# END liltress G_MODE_TEST" { skip = 0; next }
        skip { next }
        { print }
    ' /etc/hosts > "${tmp}"
    cat "${tmp}" > /etc/hosts
    rm -f "${tmp}"
    g_log_success "Noms de domaine retirés de /etc/hosts"
}

g_apply_mode_test_local() {
    [[ "${G_MODE_TEST:-0}" == "1" ]] || return 0

    local live="/etc/letsencrypt/live/${S_DOMAIN}"
    g_log_info "Préparation de l'accès local G_MODE_TEST"
    mkdir -p "${live}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout "${live}/privkey.pem" \
        -out "${live}/fullchain.pem" \
        -subj "/CN=${S_DOMAIN}" >/dev/null 2>&1
    chmod 640 "${live}/privkey.pem"
    chmod 644 "${live}/fullchain.pem"

    g_strip_mode_test_host
    if [[ -f /usr/local/share/ca-certificates/liltress-mode-test.crt ]]; then
        g_log_info "Retrait du certificat de test du magasin système"
        rm -f /usr/local/share/ca-certificates/liltress-mode-test.crt
        update-ca-certificates >/dev/null || true
        g_log_success "Certificat de test retiré du magasin système"
    fi
    g_log_success "Accès local G_MODE_TEST prêt, navigateur sur http://127.0.0.1"
}

g_get_current_user() {
    local u="${SUDO_USER:-${W_USER:-}}"
    if [[ -z "$u" || "$u" == "root" ]]; then
        u="$(awk -F: '$3 >= 1000 && $3 < 65534 && $1 != "nobody" { print $1; exit }' /etc/passwd)"
    fi
    if [[ -z "$u" ]]; then
        g_log_error "Impossible de déterminer l'utilisateur courant (SUDO_USER vide, aucun uid≥1000)."
    fi
    CURRENT_USER="$u"
    CURRENT_GROUP="$(id -gn "$CURRENT_USER")"
    CURRENT_HOME="$(getent passwd "$CURRENT_USER" | awk -F: '{print $6}')"
    export CURRENT_USER CURRENT_GROUP CURRENT_HOME
}

# Ubuntu itself, release 26.04 or newer. A derivative is refused.
g_check_ubuntu_base() {
    local os_id="${ID:-}"
    local os_codename="${UBUNTU_CODENAME:-}"
    local version_id="${VERSION_ID:-}"
    local pretty="${PRETTY_NAME:-${OS_PRETTY:-inconnu}}"
    local base_version=""

    if [[ "${os_id}" != "ubuntu" ]]; then
        g_log_error "Ubuntu 26.04 ou plus récent requis. Système détecté : ${pretty}."
    fi

    if [[ "${version_id}" =~ ^([0-9]+)\.([0-9]+) ]]; then
        base_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
    fi
    if [[ -z "${base_version}" ]]; then
        g_log_error "Ubuntu 26.04 ou plus récent requis. Version détectée : ${version_id:-aucune}."
    fi

    UBUNTU_BASE_VERSION="${base_version}"
    UBUNTU_BASE_CODENAME="${os_codename:-inconnu}"
    if ! dpkg --compare-versions "${UBUNTU_BASE_VERSION}" ge "26.04"; then
        g_log_error "Ubuntu ${UBUNTU_BASE_VERSION} (${UBUNTU_BASE_CODENAME}) refusée : elle n'est pas supérieure ou égale à 26.04."
    fi
    export UBUNTU_BASE_VERSION UBUNTU_BASE_CODENAME
}

# Return 0 when the resolved base is an LTS: even year, minor 4.
g_check_ubuntu_lts() {
    local version="${UBUNTU_BASE_VERSION:-}"
    local major=0
    local minor=0

    if [[ ! "${version}" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        return 1
    fi
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    if [[ "${minor}" -eq 4 && $((major % 2)) -eq 0 ]]; then
        return 0
    fi
    return 1
}

# Print the Postfix map type in use: hash on 26.04, cdb on 26.10.
g_get_sasl_map_type() {
    local map_type=""
    map_type="$(postconf -h default_database_type 2>/dev/null || true)"
    case "${map_type}" in
        hash|cdb|lmdb)
            printf '%s\n' "${map_type}"
            ;;
        *)
            g_log_error "Type de carte Postfix refusé : ${map_type:-aucun}."
            ;;
    esac
}

g_get_operating_system() {
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
    OS_PRETTY="${PRETTY_NAME:-}"
    export OS_ID OS_VERSION_ID OS_PRETTY
    g_check_ubuntu_base
}

w_check_desktop_account() {
    local uid="$1" home="$2" shell="$3"
    [[ "${uid}" -ge 1000 && "${uid}" -lt 60000 ]] || return 1
    [[ "${home}" == /home/* ]] || return 1
    case "${shell}" in
        */nologin|*/false) return 1 ;;
    esac
    return 0
}

g_write_account_table() {
    local dest="$1"
    local name uid gid gecos home shell groups shadow_fp maxdays
    : > "${dest}.tmp"
    while IFS=: read -r name _ uid gid gecos home shell; do
        if ! w_check_desktop_account "${uid}" "${home}" "${shell}"; then
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

W_ACCOUNT_SNAPSHOT="/var/lib/liltress-workstation/accounts/human.tsv"

g_record_account_snapshot() {
    mkdir -p /var/lib/liltress-workstation/accounts
    chmod 700 /var/lib/liltress-workstation/accounts
    g_write_account_table "${W_ACCOUNT_SNAPSHOT}"

    local n
    n="$(wc -l < "${W_ACCOUNT_SNAPSHOT}" | tr -d ' ')"
    if [[ "${n}" -lt 1 ]]; then
        g_log_error "Aucun compte de bureau sous /home : l'installateur Ubuntu doit avoir créé les utilisateurs."
    fi
}

w_strip_virt_groups() {
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

g_check_account_drift() {
    local current baseline="${W_ACCOUNT_SNAPSHOT}" norm_base norm_now
    [[ -f "${baseline}" ]] || {
        echo "snapshot des comptes absent (${baseline})"
        return 1
    }
    current="$(mktemp)"
    norm_base="$(mktemp)"
    norm_now="$(mktemp)"
    g_write_account_table "${current}"
    w_strip_virt_groups < "${baseline}" > "${norm_base}"
    w_strip_virt_groups < "${current}" > "${norm_now}"
    if cmp -s "${norm_base}" "${norm_now}"; then
        rm -f "${current}" "${norm_base}" "${norm_now}"
        return 0
    fi
    diff -u "${baseline}" "${current}" || true
    rm -f "${current}" "${norm_base}" "${norm_now}"
    return 1
}

# Read one keyword from an sshd -T dump on stdin. Match ignores keyword case.
g_read_sshd_value() {
    local keyword="${1,,}"
    awk -v key="${keyword}" 'tolower($1) == key { print tolower($2); exit }'
}

# Print one effective sshd setting. 10.2 uses lowercase, 10.5 uses canonical case.
g_get_sshd_value() {
    local keyword="${1,,}"
    sshd -T 2>/dev/null | g_read_sshd_value "${keyword}"
}

g_get_ssh_port() {
    local port="22"
    if command -v sshd >/dev/null 2>&1; then
        port="$(g_get_sshd_value port)"
        [[ -z "$port" ]] && port="22"
    fi
    SSH_PORT="$port"
    export SSH_PORT
}

g_check_virtual_machine() {
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

g_check_app() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 && return 0
    dpkg-query -W -f '${Status}\n' "$name" 2>/dev/null | grep -q 'install ok' && return 0
    flatpak info "$name" >/dev/null 2>&1 && return 0
    return 1
}

g_check_password_unchanged() {
    case "$*" in
        *chpasswd*|*passwd\ *|*" usermod -p "*|*chage*)
            g_log_error "Garde-fou : tentative de mutation de mot de passe interdite : $*"
            ;;
    esac
}

w_collect_product_logs() {
    local snap="$1"
    g_check_workstation || return 0
    {
        echo "=== unbound ==="
        systemctl status unbound --no-pager -l 2>&1 | head -n 80 || true
        echo "=== resolvectl ==="
        resolvectl status 2>&1 | head -n 120 || true
    } > "${snap}/unbound.txt" 2>&1 || true

    if command -v pro >/dev/null 2>&1; then
        pro status 2>&1 | sed -E 's/[A-Za-z0-9]{20,}/[redacted]/g' > "${snap}/ubuntu-pro.txt" || true
    fi

    g_copy_unit_journals "${snap}" \
        unbound fail2ban crowdsec crowdsec-firewall-bouncer \
        auditd clamav-daemon clamav-freshclam clamonacc postfix ssh cron \
        unattended-upgrades apparmor \
        || true
}

g_check_ubuntu_pro() {
    command -v pro >/dev/null 2>&1 || return 1
    local st
    st="$(pro status --format json 2>/dev/null || true)"
    if [[ -n "$st" ]] && command -v jq >/dev/null 2>&1; then
        echo "$st" | jq -e '.attached == true' >/dev/null 2>&1 && return 0
    fi
    pro status 2>/dev/null | grep -qiE 'This machine is attached|machine is attached to an Ubuntu Pro|est attachée|Attached:[[:space:]]*(yes|true)' && return 0
    return 1
}
