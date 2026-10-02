#!/usr/bin/env bash
# =============================================================================
# Fichier    : lib.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   lib.sh — fonctions communes
# =============================================================================

# Chargé par run.sh et par chaque étape. « set -euo pipefail » s'applique
# aussi au script qui le charge : une commande en échec arrête l'étape.
#
# Les questions et le jeton Ubuntu Pro sont traités par configure.sh.
# Ce fichier ne demande rien à l'utilisateur.
# =============================================================================

set -euo pipefail


HF_PRODUCT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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
