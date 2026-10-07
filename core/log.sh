#!/usr/bin/env bash
# =============================================================================
# File       : core/log.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

blue()    { printf "\e[34m%s\e[0m\n"               "$*" >&2; }
violet()  { printf "\e[35m%s\e[0m\n"               "$*" >&2; }
red()     { printf "\e[31m%s\e[0m\n"               "$*" >&2; }

hf_fit() {
    local text="$1"
    local max="${2:-62}"
    local n="${#text}"
    if (( max < 4 || n <= max )); then
        if (( n > max && max > 0 )); then
            printf '%s' "${text:0:max}"
            return 0
        fi
        printf '%s' "$text"
        return 0
    fi
    printf '%s...' "${text:0:$((max - 3))}"
}

hf_disp_path() {
    local p="$1"
    case "$p" in
        */logs|*/logs/*)
            printf '%s' "/logs${p#*/logs}"
            ;;
        *)
            printf '%s' "$p"
            ;;
    esac
}

hf_shorten_logs_paths() {
    local rest="$1"
    local out="" pre path
    while [[ "$rest" == *"/logs"* ]]; do
        pre="${rest%%/logs*}"
        rest="${rest#*/logs}"
        if [[ "$pre" =~ ^(.*[^/[:alnum:]._+~-])(/[[:alnum:]._+~/-]*)$ ]]; then
            out+="${BASH_REMATCH[1]}"
        elif [[ "$pre" == /* ]]; then
            :
        else
            out+="$pre"
        fi
        path="/logs"
        if [[ "$rest" =~ ^(/[[:alnum:]._+~/-]*) ]]; then
            path+="${BASH_REMATCH[1]}"
            rest="${rest:${#BASH_REMATCH[1]}}"
        fi
        out+="$path"
    done
    printf '%s%s' "$out" "$rest"
}

_hf_emit() {
    local tag="$1"
    local msg="$2"
    local max="$3"
    if [[ "$tag" != "DEBUG" ]]; then
        msg="$(hf_shorten_logs_paths "$msg")"
    fi
    if (( max > 0 )); then
        msg="$(hf_fit "$msg" "$max")"
    fi
    case "$tag" in
        INFO)    printf "   \e[34m   [INFO]\e[0m  %s\n" "$msg" >&2 ;;
        SUCCESS) printf "   \e[32m[SUCCESS]\e[0m  %s\n" "$msg" >&2 ;;
        WARNING) printf "   \e[33m[WARNING]\e[0m  %s\n" "$msg" >&2 ;;
        DEBUG)   printf "   \e[90m  [DEBUG]\e[0m  %s\n" "$msg" >&2 ;;
    esac
}

info()    { _hf_emit INFO    "$*" "${HF_FIT_MAX:-62}"; }
success() { _hf_emit SUCCESS "$*" "${HF_FIT_MAX:-62}"; }
warn()    { _hf_emit WARNING "$*" "${HF_FIT_MAX:-62}"; }
debug()   { _hf_emit DEBUG   "$*" 0; }

require_root() {
    [[ "$EUID" -eq 0 ]] || error "Ce script doit être exécuté avec sudo ou en root."
}

step_on() {

    if [[ "${HF_STEP_BANNERS:-0}" -eq 1 ]]; then
        echo "" >&2
    fi
    HF_STEP_BANNERS=1
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

hf_debug_logs_enabled() {
    [[ "${HF_DEBUG_INSTALL_LOGS:-0}" == "1" || "${DEBUG_INSTALL_LOGS:-0}" == "1" ]]
}

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

    local og file
    og="$(stat -c '%u:%g' "$abs_root" 2>/dev/null || true)"

    if [[ -f "$path" ]]; then
        if hf_log_path_is_private "$path"; then
            rm -f "$path"
            return 0
        fi
        chmod 644 "$path" 2>/dev/null || true
        if [[ -n "$og" && "$og" != "0:0" ]]; then
            chown "$og" "$path" 2>/dev/null || true
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
            chmod 644 "$file" 2>/dev/null || true
        fi
        if [[ -n "$og" && "$og" != "0:0" ]]; then
            chown "$og" "$file" 2>/dev/null || true
        fi
    done < <(find "$path" -print 2>/dev/null)
}

hf_publish_install_dir_logs() { hf_publish_repo_logs "$@"; }

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
}

init_install_log() {
    local root="${DIR_INSTALL_PATH:-.}"
    local stamp name kind old_umask
    stamp="$(date '+%Y%m%d-%H%M%S')"
    kind="${SERVER_TYPE:-}"
    if [[ -z "${kind}" ]]; then
        if declare -F hf_is_workstation >/dev/null 2>&1 && hf_is_workstation; then
            kind="user"
        else
            kind="unknown"
        fi
    fi
    name="install-${stamp}-${kind}"

    HF_LOG_DIR="${root}/logs/${name}"
    HF_LOG_SYS=""
    old_umask="$(umask)"
    umask 022
    mkdir -p "${HF_LOG_DIR}/steps"
    HF_LOG_FILE="${HF_LOG_DIR}/install.log"
    : > "${HF_LOG_FILE}"
    umask "${old_umask}"
    export HF_LOG_DIR HF_LOG_FILE HF_LOG_SYS

    {
        echo "${PROJECT_NAME:-High-Fortress} install log"
        echo "date        : $(date -Iseconds)"
        echo "hostname    : $(hostname 2>/dev/null || echo '?')"
        echo "user        : ${CURRENT_USER:-}"
        echo "SERVER_TYPE : ${SERVER_TYPE:-}"
        echo "MODE_TEST   : ${MODE_TEST:-}"
        echo "MODE_DEV    : ${MODE_DEV:-}"
        echo "DIR         : ${root}"
        echo "log dir     : ${HF_LOG_DIR}"
        echo "uname       : $(uname -a 2>/dev/null || true)"
    } | tee "${HF_LOG_DIR}/meta.txt" >/dev/null

    exec > >(tee -a "${HF_LOG_FILE}") 2>&1
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
    hf_copy_installed_logs "${snap}" || true

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
    info "Copie : ${snap}"
    hf_collect_common_snapshot "${snap}"

    if declare -F hf_collect_product_logs >/dev/null 2>&1; then
        hf_collect_product_logs "${snap}" || true
    fi
    if declare -F hfu_collect_product_logs >/dev/null 2>&1; then
        hfu_collect_product_logs "${snap}" || true
    fi

    {
        echo "collect_install_logs: $(date -Iseconds)"
        echo "dossier : ${HF_LOG_DIR}"
        echo "voir install.log, errors.log et steps/INDEX.tsv"
        echo "logiciels : snapshot/software/ et snapshot/journal/"
    } > "${snap}/COLLECTED.txt"

    info "Journaux logiciels copiés"
    hf_publish_repo_logs "${HF_LOG_DIR}"
}

hf_install_exit() {
    local code=$?
    if [[ "${code}" -ne 0 ]]; then
        collect_install_logs || true
    fi
    hf_publish_repo_logs "${HF_LOG_DIR:-}" || true
}

hf_ask() {
    local label="$1"
    local __var="$2"
    local width="${#label}"
    local value=""
    if (( width < 12 )); then
        width=12
    fi
    echo "" >&2
    printf '         \e[34m%*s\e[0m : ' "${width}" "${label}" >&2
    IFS= read -r value < /dev/tty || error "Entrée interrompue."
    printf -v "${__var}" '%s' "${value}"
}

hf_installer_dir_ok() {
    local root="$1"
    local base="$2"
    [[ -n "${root}" && "${root}" == /* && -d "${root}" ]] || return 1
    [[ "${root}" != *[[:space:]]* && "${root}" != *$'\n'* ]] || return 1
    case "${root}" in
        /|/opt|/usr|/bin|/sbin|/lib|/lib64|/etc|/var|/home|/boot|/tmp|/root|/srv|/proc|/sys|/dev|/run)
            return 1
            ;;
    esac
    [[ "${root#/}" == */* ]] || return 1
    [[ -f "${root}/hf" && -f "${root}/scripts/run.sh" ]] || return 1
    [[ -n "${base}" && "${base}" == /* && -d "${base}" ]] || return 1
    [[ "${base}" != *[[:space:]]* ]] || return 1

    case "${base}/" in
        "${root}/"*) return 1 ;;
    esac
    return 0
}

hf_remove_installer_tree() {
    local root="" base="" mail="" conf="" tmp="" back="" rm_rc=0
    root="$(cd -- "${DIR_INSTALL_PATH:?}" && pwd -P)" || return 1
    base="$(cd -- "${CONFIG_BASE_DIR:?}" && pwd -P)" || return 1
    hf_installer_dir_ok "${root}" "${base}" || return 1
    if [[ -f "${root}/core/mail.sh" ]]; then
        mail="${root}/core/mail.sh"
    elif [[ -f "${root}/../core/mail.sh" ]]; then
        mail="${root}/../core/mail.sh"
    else
        return 2
    fi
    conf="${root}/config/global.conf"
    [[ -f "${conf}" ]] || return 2
    tmp="$(mktemp -d)" || return 2
    if ! install -m 644 -- "${conf}" "${tmp}/global.conf" \
        || ! install -m 644 -- "${mail}" "${tmp}/mail.sh"; then
        rm -rf -- "${tmp}"
        return 2
    fi
    back="$(pwd -P 2>/dev/null || true)"
    cd / || { rm -rf -- "${tmp}"; return 1; }
    rm -rf -- "${root}" || rm_rc=$?
    if ! install -d -m 755 -- "${base}/src" "${base}/src/core" "${base}/src/config" \
        || ! install -m 644 -- "${tmp}/global.conf" "${base}/src/config/global.conf" \
        || ! install -m 644 -- "${tmp}/mail.sh" "${base}/src/core/mail.sh"; then
        rm -rf -- "${tmp}"
        if [[ -n "${back}" && -d "${back}" ]]; then
            cd -- "${back}" || true
        fi
        return 4
    fi
    rm -rf -- "${tmp}"
    if [[ -n "${back}" && -d "${back}" ]]; then
        cd -- "${back}" || true
    fi
    if [[ "${rm_rc}" -ne 0 || -e "${root}/hf" || -e "${root}/config/secrets.conf" || -e "${root}/scripts/run.sh" ]]; then
        return 3
    fi
    [[ -f "${base}/src/config/global.conf" && -f "${base}/src/core/mail.sh" ]] || return 4
    [[ ! -e "${base}/src/config/secrets.conf" || "${root}" != "${base}/src" ]] || return 3
    return 0
}

hf_refresh_aide_after_remove() {
    local base="${CONFIG_BASE_DIR:-}"
    local log="/var/lib/aide/hf-remove-refresh.log"
    local aide_rc=0
    [[ -n "${base}" && -f /etc/aide/aide.conf ]] || return 0
    command -v aide >/dev/null 2>&1 || return 0
    grep -qF -- "${base}" /etc/aide/aide.conf || return 0
    info "Recalcul de la base AIDE (plusieurs minutes)"
    mkdir -p /var/lib/aide || {
        warn "Base AIDE non recalculée."
        return 0
    }
    rm -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db.new.gz
    aide --config=/etc/aide/aide.conf --init >"${log}" 2>&1 || aide_rc=$?
    if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
        if ! mv -f /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz; then
            warn "Base AIDE non recalculée."
            return 0
        fi
        ln -sfn /var/lib/aide/aide.db.gz /var/lib/aide/aide.db || true
    elif [[ -f /var/lib/aide/aide.db.new ]]; then
        if ! mv -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db; then
            warn "Base AIDE non recalculée."
            return 0
        fi
    else
        warn "Base AIDE non recalculée."
        HF_FIT_MAX=0 warn "Détail : ${log}"
        return 0
    fi
    if [[ "${aide_rc}" -ne 0 ]]; then
        warn "Code aide ${aide_rc}. La base produite est en service."
    fi
    success "Base AIDE recalculée"
    return 0
}

hf_offer_remove_installer() {
    local root="" base="" answer="" rc=0
    if [[ "${MODE_TEST:-0}" == "1" || "${MODE_DEV:-0}" == "1" ]]; then
        return 0
    fi
    if [[ ! -r /dev/tty ]]; then
        warn "Pas de terminal : l'installeur est conservé."
        return 0
    fi
    root="$(cd -- "${DIR_INSTALL_PATH:?}" && pwd -P)" || {
        warn "Suppression annulée : répertoire refusé."
        return 0
    }
    base="${CONFIG_BASE_DIR:-}"

    title "Suppression de l'installeur"
    info "Supprimer l'installeur et ses journaux ? (Y/N)"
    HF_FIT_MAX=0 info "Répertoire : ${root}"
    while true; do
        hf_ask "Supprimer" answer
        answer="${answer#"${answer%%[![:space:]]*}"}"
        answer="${answer%"${answer##*[![:space:]]}"}"
        case "${answer,,}" in
            y) break ;;
            n) return 0 ;;
            *) warn "Répondez Y ou N." ;;
        esac
    done
    info "Retrait de l'installeur"
    hf_remove_installer_tree || rc=$?
    echo "" >&2
    case "${rc}" in
        0)
            success "Installeur retiré."
            info "Services, secrets et cron conservés."
            if [[ ! -e "${root}/hf" && ! -e "${base}/src/hf" ]]; then
                info "La commande hf n'est plus disponible."
            fi
            hf_refresh_aide_after_remove || true
            ;;
        1)
            warn "Suppression annulée : répertoire refusé."
            ;;
        2)
            warn "Suppression annulée : fichier utile absent."
            ;;
        3)
            warn "Suppression incomplète."
            hf_refresh_aide_after_remove || true
            ;;
        *)
            warn "Installeur retiré, fichiers utiles non reposés."
            hf_refresh_aide_after_remove || true
            ;;
    esac
    return 0
}

hf_collect_manual() {
    local root="${DIR_INSTALL_PATH:-.}"
    local stamp name old_umask
    stamp="$(date '+%Y%m%d-%H%M%S')"
    name="snapshot-${stamp}-$(hostname -s 2>/dev/null || hostname)"
    SERVER_TYPE="${SERVER_TYPE:-manual}"
    HF_LOG_DIR="${root}/logs/${name}"
    HF_LOG_SYS=""
    old_umask="$(umask)"
    umask 022
    mkdir -p "${HF_LOG_DIR}/snapshot"
    umask "${old_umask}"
    export HF_LOG_DIR HF_LOG_SYS SERVER_TYPE
    unset HF_LOGS_COLLECTED
    collect_install_logs
    info "Snapshot : ${HF_LOG_DIR}"
}

hf_log_copy_max_bytes() {
    printf '%s\n' 8388608
}

hf_log_note() {
    local snap="${HF_LOG_DIR:-}"
    [[ -n "${snap}" ]] || return 0
    mkdir -p "${snap}/snapshot"
    printf '%s\n' "$1" >> "${snap}/snapshot/truncated.txt"
}

hf_copy_log_file() {
    local src="$1"
    local dest="$2"
    local max size
    [[ -f "${src}" ]] || return 0
    if hf_log_path_is_private "${src}"; then
        return 0
    fi
    [[ -r "${src}" ]] || {
        hf_log_note "illisible ${src}"
        return 0
    }
    max="$(hf_log_copy_max_bytes)"
    size="$(stat -c '%s' "${src}" 2>/dev/null || echo 0)"
    mkdir -p "$(dirname "${dest}")"
    case "${src}" in
        *.gz|*.xz|*.zst)
            if [[ "${size}" -gt "${max}" ]]; then
                hf_log_note "ignoré (compressé, ${size} octets) ${src}"
                return 0
            fi
            cp -f -- "${src}" "${dest}" 2>/dev/null || return 0
            ;;
        *)
            if [[ "${size}" -gt "${max}" ]]; then
                tail -c "${max}" "${src}" > "${dest}" 2>/dev/null || return 0
                hf_log_note "fin de fichier seulement (${size} octets, ${max} gardés) ${src}"
            else
                cp -f -- "${src}" "${dest}" 2>/dev/null || return 0
            fi
            ;;
    esac
    chmod 644 "${dest}" 2>/dev/null || true
}

hf_copy_log_tree() {
    local src="$1"
    local dest_root="$2"
    local file dest
    [[ -e "${src}" ]] || return 0
    if [[ -f "${src}" ]]; then
        hf_copy_log_file "${src}" "${dest_root}/${src#/}"
        return 0
    fi
    [[ -d "${src}" ]] || return 0
    while IFS= read -r -d '' file; do
        dest="${dest_root}/${file#/}"
        hf_copy_log_file "${file}" "${dest}"
    done < <(find "${src}" -type f -print0 2>/dev/null)
    return 0
}

hf_copy_installed_logs() {
    local snap="$1"
    local dest="${snap}/software"
    local src
    local -a paths=(
        /var/log/syslog
        /var/log/auth.log
        /var/log/kern.log
        /var/log/nginx
        /var/log/fail2ban.log
        /var/log/ufw.log
        /var/log/clamav
        /var/log/aide
        /var/lib/aide/aide.log
        /var/log/rkhunter.log
        /var/log/audit
        /var/log/crowdsec
        /var/log/mail.log
        /var/log/mail.err
        /var/log/redis
        /var/log/unattended-upgrades
        /var/log/letsencrypt
        /var/log/apt/term.log
        /var/log/apt/history.log
        /var/log/dpkg.log
    )
    for src in "${paths[@]}"; do
        hf_copy_log_tree "${src}" "${dest}"
    done
    if [[ -n "${CONFIG_BASE_DIR:-}" ]]; then
        hf_copy_log_tree "${CONFIG_BASE_DIR}/cron/cron_logs" "${dest}"
        hf_copy_log_tree "${CONFIG_BASE_DIR}/cron/security_logs" "${dest}"
        hf_copy_log_tree "${CONFIG_BASE_DIR}/cron/alerts" "${dest}"
    fi
    return 0
}

hf_copy_unit_journals() {
    local snap="$1"
    shift
    local unit
    mkdir -p "${snap}/journal"
    for unit in "$@"; do
        systemctl cat "${unit}" >/dev/null 2>&1 || continue
        journalctl -u "${unit}" -b --no-pager -n 2000 > "${snap}/journal/${unit}.log" 2>&1 || true
        chmod 644 "${snap}/journal/${unit}.log" 2>/dev/null || true
    done
    return 0
}
