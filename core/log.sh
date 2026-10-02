#!/usr/bin/env bash
# Journaux, messages et publication vers le dossier partagé.
# Aucun réglage de sécurité propre au serveur ou au poste.

blue()    { printf "\e[34m%s\e[0m\n"               "$*" >&2; }
violet()  { printf "\e[35m%s\e[0m\n"               "$*" >&2; }
red()     { printf "\e[31m%s\e[0m\n"               "$*" >&2; }
info()    { printf "   \e[34m   [INFO]\e[0m  %s\n" "$*" >&2; }
success() { printf "   \e[32m[SUCCESS]\e[0m  %s\n" "$*" >&2; }
warn()    { printf "   \e[33m[WARNING]\e[0m  %s\n" "$*" >&2; }
debug()   { printf "   \e[90m  [DEBUG]\e[0m  %s\n" "$*" >&2; }

require_root() {
    [[ "$EUID" -eq 0 ]] || error "Ce script doit être exécuté avec sudo ou en root."
}

step_on() {
    echo "" >&2
    violet "═════════════════════════════════════════════════════════════════════════════════"
    violet " # $*"
    violet "═══ ↓ ↓ ═════════════════════════════════════════════════════════════════ ↓ ↓ ═══"
}

step_off() {
    echo "" >&2
    violet "═══ ↑ ↑ ═════════════════════════════════════════════════════════════════ ↑ ↑ ═══"
    violet " # $*"
    violet "═════════════════════════════════════════════════════════════════════════════════"
    echo "" >&2
}

title() {
    echo "" >&2
    blue "  -----------------------------------------------------------------------------"
    blue "   $*"
    blue "  -----------------------------------------------------------------------------"
    echo "" >&2
}

error (){
    echo ""
    red "  -----------------------------------------------------------------------------"
    red "   $*"
    red "  -----------------------------------------------------------------------------"
    echo ""
    if [[ -n "${HF_LOG_DIR:-}" ]]; then
        printf '%s\n' "$*" >> "${HF_LOG_DIR}/errors.log" 2>/dev/null || true
        info "Journaux : ${HF_LOG_DIR}"
    fi
    exit 1
}

# 1 si la copie dans le dépôt est demandée.
# HF_DEBUG_INSTALL_LOGS (environnement, VM) prime comme interrupteur additionnel.
# DEBUG_INSTALL_LOGS reste lu dans global.conf. Le défaut publié est 0.
hf_debug_logs_enabled() {
    [[ "${HF_DEBUG_INSTALL_LOGS:-0}" == "1" || "${DEBUG_INSTALL_LOGS:-0}" == "1" ]]
}

# Nom de fichier qui ne doit jamais devenir lisible sur le partage.
hf_log_path_is_private() {
    local path="$1"
    local base
    base="$(basename "${path}")"
    case "${base}" in
        secrets.conf|human.tsv|*.env|*.key|id_ed25519*|htpasswd*|*.htpasswd)
            return 0
            ;;
    esac
    case "${path}" in
        */accounts|*/accounts/*)
            return 0
            ;;
    esac
    return 1
}

# Rend $1 (sous DIR_INSTALL_PATH) lisible par l'utilisateur de l'hôte.
# Les fichiers privés sont retirés de cette copie. Ils restent sur la VM.
hf_publish_repo_logs() {
    local path="${1:-}"
    local root="${DIR_INSTALL_PATH:-}"
    [[ -n "$path" && -e "$path" && -n "$root" ]] || return 0
    local abs_root abs_path
    abs_root="$(cd "$root" 2>/dev/null && pwd)" || return 0
    if [[ -d "$path" ]]; then
        abs_path="$(cd "$path" 2>/dev/null && pwd)" || return 0
    else
        abs_path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")" || return 0
    fi
    [[ "$abs_path" == "$abs_root" || "$abs_path" == "${abs_root}/"* ]] || return 0

    local og mode file
    og="$(stat -c '%u:%g' "$abs_root" 2>/dev/null || true)"

    if [[ -f "$path" ]]; then
        if hf_log_path_is_private "$path"; then
            rm -f "$path"
            return 0
        fi
        mode="$(stat -c '%a' "$path" 2>/dev/null || echo 644)"
        if [[ "${mode}" != "600" && "${mode}" != "400" ]]; then
            chmod 644 "$path" 2>/dev/null || true
            if [[ -n "$og" && "$og" != "0:0" ]]; then
                chown "$og" "$path" 2>/dev/null || true
            fi
        fi
        return 0
    fi

    while IFS= read -r file; do
        if hf_log_path_is_private "$file"; then
            rm -f "$file"
        fi
    done < <(find "$path" -type f -print 2>/dev/null)

    find "$path" -type d -empty -name accounts -exec rmdir {} + 2>/dev/null || true

    while IFS= read -r file; do
        [[ -e "$file" ]] || continue
        if [[ -d "$file" ]]; then
            chmod 755 "$file" 2>/dev/null || true
        else
            mode="$(stat -c '%a' "$file" 2>/dev/null || echo 644)"
            if [[ "${mode}" == "600" || "${mode}" == "400" ]]; then
                continue
            fi
            chmod 644 "$file" 2>/dev/null || true
        fi
        if [[ -n "$og" && "$og" != "0:0" ]]; then
            chown "$og" "$file" 2>/dev/null || true
        fi
    done < <(find "$path" -print 2>/dev/null)
}

hf_log_index_append() {
    local step="$1"
    local exit_code="$2"
    local log_path="$3"
    local line
    line="$(date -Iseconds)"$'\t'"${step}"$'\t'"${exit_code}"$'\t'"${log_path}"
    if [[ -n "${HF_LOG_DIR:-}" ]]; then
        mkdir -p "${HF_LOG_DIR}/steps"
        printf '%s\n' "${line}" >> "${HF_LOG_DIR}/steps/INDEX.tsv"
    fi
    if [[ -n "${HF_LOG_SYS:-}" && "${HF_LOG_SYS}" != "${HF_LOG_DIR:-}" ]]; then
        mkdir -p "${HF_LOG_SYS}/steps"
        printf '%s\n' "${line}" >> "${HF_LOG_SYS}/steps/INDEX.tsv"
    fi
}

init_install_log() {
    local root="${DIR_INSTALL_PATH:-.}"
    local stamp name slug
    stamp="$(date '+%Y%m%d-%H%M%S')"
    slug="${PROJECT_SLUG:-high-fortress}"
    name="install-${stamp}-${SERVER_TYPE:-unknown}"

    HF_LOG_SYS="/var/log/${slug}/${name}"
    mkdir -p "${HF_LOG_SYS}/steps" "${HF_LOG_SYS}/snapshot"
    # Le poste relit ses journaux sans rester root. Le serveur les garde root.
    if [[ "${slug}" == "high-fortress-user" ]]; then
        chmod 755 "/var/log/${slug}" "${HF_LOG_SYS}" "${HF_LOG_SYS}/steps" "${HF_LOG_SYS}/snapshot" 2>/dev/null || true
    fi

    if hf_debug_logs_enabled; then
        HF_LOG_DIR="${root}/logs/${name}"
        local old_umask
        old_umask="$(umask)"
        umask 022
        mkdir -p "${HF_LOG_DIR}/steps" "${HF_LOG_DIR}/snapshot"
        umask "${old_umask}"
        hf_publish_repo_logs "${HF_LOG_DIR}"
    else
        HF_LOG_DIR="${HF_LOG_SYS}"
    fi

    HF_LOG_FILE="${HF_LOG_DIR}/install.log"
    : > "${HF_LOG_FILE}"
    export HF_LOG_DIR HF_LOG_FILE HF_LOG_SYS

    {
        echo "${PROJECT_NAME:-High-Fortress} install log"
        echo "date        : $(date -Iseconds)"
        echo "hostname    : $(hostname 2>/dev/null || echo '?')"
        echo "user        : ${CURRENT_USER:-}"
        echo "SERVER_TYPE : ${SERVER_TYPE:-}"
        echo "MODE_TEST   : ${MODE_TEST:-}"
        echo "MODE_DEV    : ${MODE_DEV:-}"
        echo "DEBUG_INSTALL_LOGS : ${DEBUG_INSTALL_LOGS:-0}"
        echo "HF_DEBUG_INSTALL_LOGS : ${HF_DEBUG_INSTALL_LOGS:-0}"
        echo "DIR         : ${root}"
        echo "log dir     : ${HF_LOG_DIR}"
        echo "log sys     : ${HF_LOG_SYS}"
        echo "uname       : $(uname -a 2>/dev/null || true)"
    } | tee "${HF_LOG_DIR}/meta.txt" >/dev/null

    if [[ "${HF_LOG_DIR}" != "${HF_LOG_SYS}" ]]; then
        exec > >(tee -a "${HF_LOG_FILE}" "${HF_LOG_SYS}/install.log") 2>&1
        info "Journaux (debug dépôt) : ${HF_LOG_DIR}"
        info "Journaux (machine)     : ${HF_LOG_SYS}"
    else
        exec > >(tee -a "${HF_LOG_FILE}") 2>&1
        info "Journaux (machine) : ${HF_LOG_DIR}"
    fi
    hf_publish_repo_logs "${HF_LOG_DIR}"
}

hf_collect_common_snapshot() {
    local snap="$1"
    mkdir -p "${snap}"

    {
        hostnamectl 2>/dev/null || hostname
        echo "---"
        date -Iseconds
        echo "---"
        uptime
        echo "---"
        uname -a
        echo "---"
        echo "CURRENT_USER=${CURRENT_USER:-}"
        echo "SERVER_TYPE=${SERVER_TYPE:-}"
    } > "${snap}/host.txt" 2>&1 || true

    {
        echo "=== ip ==="
        ip -br a 2>/dev/null || ifconfig 2>/dev/null || true
        echo "=== df ==="
        df -h 2>/dev/null || true
        echo "=== units failed ==="
        systemctl --failed --no-pager 2>/dev/null || true
        echo "=== timers ==="
        systemctl list-timers --no-pager 2>/dev/null || true
        echo "=== kvm ==="
        ls -l /dev/kvm 2>/dev/null || true
        echo "=== virsh ==="
        virsh list --all 2>/dev/null || true
    } > "${snap}/system.txt" 2>&1 || true

    journalctl -b --no-pager -n 4000 > "${snap}/journalctl-boot.txt" 2>&1 || true
    dmesg -T 2>/dev/null | tail -n 500 > "${snap}/dmesg.txt" || true

    local f
    for f in /var/log/syslog /var/log/auth.log /var/log/nginx/error.log /var/log/nginx/access.log \
             /var/log/fail2ban.log /var/log/ufw.log /var/log/clamav/clamav.log \
             /var/log/unattended-upgrades/unattended-upgrades.log; do
        if [[ -r "$f" ]]; then
            tail -n 400 "$f" > "${snap}/$(echo "$f" | tr '/' '_').tail.txt" 2>/dev/null || true
        fi
    done

    ufw status verbose > "${snap}/ufw-status.txt" 2>&1 || true
    sshd -t > "${snap}/sshd-t.txt" 2>&1 || true
    sshd -T > "${snap}/sshd-T.txt" 2>&1 || true
    aa-status > "${snap}/apparmor-status.txt" 2>&1 || true
}

collect_install_logs() {
    [[ -n "${HF_LOG_DIR:-}" && -d "${HF_LOG_DIR}" ]] || return 0
    [[ "${HF_LOGS_COLLECTED:-0}" == "1" ]] && return 0
    HF_LOGS_COLLECTED=1
    export HF_LOGS_COLLECTED

    local snap="${HF_LOG_DIR}/snapshot"
    mkdir -p "$snap"
    info "Copie des journaux système vers ${snap} ..."
    hf_collect_common_snapshot "${snap}"

    if declare -F hf_collect_product_logs >/dev/null 2>&1; then
        hf_collect_product_logs "${snap}"
    fi
    if declare -F hfu_collect_product_logs >/dev/null 2>&1; then
        hfu_collect_product_logs "${snap}"
    fi

    {
        echo "collect_install_logs: $(date -Iseconds)"
        echo "exit note: see install.log, errors.log and steps/INDEX.tsv"
    } > "${snap}/COLLECTED.txt"

    info "Snapshot copié dans ${snap}"

    if [[ -n "${HF_LOG_SYS:-}" && "${HF_LOG_SYS}" != "${HF_LOG_DIR}" ]]; then
        mkdir -p "${HF_LOG_SYS}"
        cp -a "${HF_LOG_DIR}/." "${HF_LOG_SYS}/" 2>/dev/null || true
    fi
    hf_publish_repo_logs "${HF_LOG_DIR}"
}

# Snapshot manuel. Même contrat que l'install : partage seulement si le debug est actif.
hf_collect_manual() {
    local root="${DIR_INSTALL_PATH:-.}"
    local slug stamp name
    slug="${PROJECT_SLUG:-high-fortress}"
    stamp="$(date '+%Y%m%d-%H%M%S')"
    name="snapshot-${stamp}-$(hostname -s 2>/dev/null || hostname)"
    SERVER_TYPE="${SERVER_TYPE:-manual}"
    HF_LOG_SYS="/var/log/${slug}/${name}"
    if hf_debug_logs_enabled; then
        HF_LOG_DIR="${root}/logs/${name}"
    else
        HF_LOG_DIR="${HF_LOG_SYS}"
    fi
    mkdir -p "${HF_LOG_DIR}/snapshot" "${HF_LOG_SYS}/snapshot"
    export HF_LOG_DIR HF_LOG_SYS SERVER_TYPE
    unset HF_LOGS_COLLECTED
    collect_install_logs
    info "Snapshot : ${HF_LOG_DIR}"
}
