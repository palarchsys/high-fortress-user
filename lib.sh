#!/usr/bin/env bash
# =============================================================================
# lib.sh — fonctions communes High-Fortress User
# =============================================================================
# Sourcé par run.sh et chaque étape (install/configure).
# set -euo pipefail s'applique aussi au script appelant.
# =============================================================================

set -euo pipefail

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

step_on (){
  echo ""
  violet "═════════════════════════════════════════════════════════════════════════════════"
  violet " # $*"
  violet "═══ ↓ ↓ ═════════════════════════════════════════════════════════════════ ↓ ↓ ═══"
}

step_off (){
  echo ""
  violet "═══ ↑ ↑ ═════════════════════════════════════════════════════════════════ ↑ ↑ ═══"
  violet " # $*"
  violet "═════════════════════════════════════════════════════════════════════════════════"
  echo ""
}

title (){
  echo ""
  blue "  -----------------------------------------------------------------------------"
  blue "   $*"
  blue "  -----------------------------------------------------------------------------"
  echo ""
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

run_silent() {
    local cmd_output
    local exit_code=0

    cmd_output=$("$@" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi

    error "$cmd_output"
}

try_silent() {
    local cmd_output
    local exit_code=0

    cmd_output=$("$@" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 && -n "$cmd_output" ]]; then
        debug "$cmd_output"
    fi
    return 0
}

run_silent_apt() {
    local cmd_output
    local exit_code=0
    local attempt=0
    local max_attempts=30

    sleep 1

    while [[ $attempt -lt $max_attempts ]]; do
        cmd_output=$(DEBIAN_FRONTEND=noninteractive apt-get "$@" 2>&1) || exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            return 0
        fi

        if echo "$cmd_output" | grep -qE "Could not get lock|verrou|lock-frontend|unattended-upgr"; then
            attempt=$((attempt + 1))
            exit_code=0
            sleep 2
            continue
        fi

        error "$cmd_output"
    done

    error "Timeout : verrou apt toujours occupé après ${max_attempts} tentatives !"
}

run_steps() {
    local dir_install_path="$1"
    local server_type="$2"
    shift 2
    local -a steps=("$@")

    [[ ${#steps[@]} -eq 0 ]] && error "Aucun step fourni"
    [[ -z "$dir_install_path" || ! -d "$dir_install_path" ]] && error "dir_install_path invalide : '$dir_install_path'"

    for step in "${steps[@]}"; do
        local full_path="${dir_install_path}/${step}"
        step_on "Exécution de ${step}"

        if [[ ! -f "$full_path" ]]; then
            error "Fichier introuvable : $full_path"
        fi

        local step_exit=0
        if [[ -n "${HF_LOG_DIR:-}" ]]; then
            local step_log="${HF_LOG_DIR}/steps/$(echo "$step" | tr '/' '-').log"
            mkdir -p "${HF_LOG_DIR}/steps"
            set +e
            bash "$full_path" "$dir_install_path" "$server_type" 2>&1 | tee -a "$step_log"
            step_exit=${PIPESTATUS[0]}
            set -e
        else
            bash "$full_path" "$dir_install_path" "$server_type"
            step_exit=$?
        fi

        if [[ $step_exit -ne 0 ]]; then
            exit $step_exit
        fi
    done

    return 0
}

add_line_if_missing() {
    local file="$1"
    local line="$2"
    local comment="${3:-}"
    if ! grep -qF "$line" "$file" 2>/dev/null; then
        [[ -n "$comment" ]] && echo "$comment" >> "$file"
        echo "$line" >> "$file"
    fi
}

backup_file_once() {
    local file="$1"
    local backup="${file}.bak"
    [[ -f "$file" ]] || return 0
    [[ -f "$backup" ]] && return 0
    cp -a "$file" "$backup" && success "Backup créé : $backup"
}

ensure_dir() {
    local mode="700"
    local user="root"
    local group="root"
    local dirs=()

    while [ $# -gt 0 ]; do
        case "$1" in
            [0-9]*)
                mode="$1"
                shift
                break
                ;;
            *)
                dirs+=("$1")
                shift
                ;;
        esac
    done

    if [ $# -ge 1 ]; then
        user="$1"
    fi
    if [ $# -ge 2 ]; then
        group="$2"
    fi

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod "$mode" "$dir"

        local effective_user="$user"
        local effective_group="$group"

        if ! id -u "$effective_user" >/dev/null 2>&1; then
            effective_user="root"
        fi
        if ! getent group "$effective_group" >/dev/null 2>&1; then
            effective_group="root"
        fi

        chown "${effective_user}:${effective_group}" "$dir" 2>/dev/null || true
    done
}

user_exists() {
    id "$1" >/dev/null 2>&1
}

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
    if [[ "${OS_ID}" != "ubuntu" ]]; then
        error "Système non supporté : ${OS_PRETTY} (Ubuntu 26.04 requis)."
    fi
    if [[ "${OS_VERSION_ID}" != "26.04" ]]; then
        warn "Cible prévue : Ubuntu 26.04 — détecté ${OS_PRETTY}. Poursuite prudente."
    else
        success "OS : ${OS_PRETTY}"
    fi
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
    snap list "$name" >/dev/null 2>&1 && return 0
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

# -----------------------------------------------------------------------------
# Journaux d'installation
# -----------------------------------------------------------------------------

init_install_log() {
    local root="${DIR_INSTALL_PATH:-.}"
    local stamp name
    stamp="$(date '+%Y%m%d-%H%M%S')"
    name="install-${stamp}-${SERVER_TYPE:-workstation}"

    HF_LOG_SYS="/var/log/${PROJECT_SLUG:-high-fortress-user}/${name}"
    mkdir -p "${HF_LOG_SYS}/steps" "${HF_LOG_SYS}/snapshot"

    if [[ "${DEBUG_INSTALL_LOGS:-0}" = "1" ]]; then
        HF_LOG_DIR="${root}/logs/${name}"
        mkdir -p "${HF_LOG_DIR}/steps" "${HF_LOG_DIR}/snapshot"
    else
        HF_LOG_DIR="${HF_LOG_SYS}"
    fi

    HF_LOG_FILE="${HF_LOG_DIR}/install.log"
    : > "${HF_LOG_FILE}"
    export HF_LOG_DIR HF_LOG_FILE HF_LOG_SYS

    {
        echo "High-Fortress User install log"
        echo "date        : $(date -Iseconds)"
        echo "hostname    : $(hostname 2>/dev/null || echo '?')"
        echo "user        : ${CURRENT_USER:-}"
        echo "SERVER_TYPE : ${SERVER_TYPE:-}"
        echo "DEBUG_INSTALL_LOGS : ${DEBUG_INSTALL_LOGS:-0}"
        echo "DIR         : ${root}"
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
}

collect_install_logs() {
    [[ -n "${HF_LOG_DIR:-}" && -d "${HF_LOG_DIR}" ]] || return 0
    [[ "${HF_LOGS_COLLECTED:-0}" == "1" ]] && return 0
    HF_LOGS_COLLECTED=1
    export HF_LOGS_COLLECTED

    local snap="${HF_LOG_DIR}/snapshot"
    mkdir -p "$snap"

    info "Copie des journaux système vers ${snap} ..."

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
    } > "${snap}/host.txt" 2>&1 || true

    {
        echo "=== ip ==="
        ip -br a 2>/dev/null || true
        echo "=== df ==="
        df -h 2>/dev/null || true
        echo "=== units failed ==="
        systemctl --failed --no-pager 2>/dev/null || true
        echo "=== kvm ==="
        ls -l /dev/kvm 2>/dev/null || true
        echo "=== virsh ==="
        virsh list --all 2>/dev/null || true
    } > "${snap}/system.txt" 2>&1 || true

    journalctl -b --no-pager -n 2000 > "${snap}/journalctl-boot.txt" 2>&1 || true

    ufw status verbose > "${snap}/ufw-status.txt" 2>&1 || true
    sshd -T > "${snap}/sshd-T.txt" 2>&1 || true
    aa-status > "${snap}/apparmor-status.txt" 2>&1 || true

    {
        echo "collect_install_logs: $(date -Iseconds)"
    } > "${snap}/COLLECTED.txt"

    if [[ -n "${HF_LOG_SYS:-}" && "${HF_LOG_SYS}" != "${HF_LOG_DIR}" ]]; then
        mkdir -p "${HF_LOG_SYS}"
        cp -a "${HF_LOG_DIR}/." "${HF_LOG_SYS}/" 2>/dev/null || true
    fi
}

ask_conf() {
    local name="$1"
    local label="$2"
    local hidden="${3:-0}"
    local current="${!name:-}"
    local input=""

    if [[ -n "$current" ]]; then
        export "$name"
        return 0
    fi

    if [[ "$hidden" = "1" ]]; then
        read -r -s -p "   ➤ ${label} : " input
        echo ""
    else
        read -r -p "   ➤ ${label} : " input
    fi
    if [[ -n "$input" ]]; then
        printf -v "$name" '%s' "$input"
    fi
    export "$name"
}

prompt_optional_secrets() {
    title "Options (tout est facultatif — Entrée = ignorer)"
    echo "   Aucun mot de passe utilisateur ne sera demandé ni modifié."
    echo ""

    local dest="${DIR_INSTALL_PATH}/secrets.conf"
    if [[ -f "$dest" ]]; then
        # shellcheck disable=SC1090
        source "$dest"
        info "secrets.conf présent — champs déjà remplis réutilisés."
        echo ""
    fi

    ask_conf UBUNTU_PRO_TOKEN "Jeton Ubuntu Pro (vide = ignorer)" 1
    ask_conf WATCHDOG_MAIL "E-mail d'alertes watchdogs (vide = journaux locaux seulement)"

    local old_umask
    old_umask="$(umask)"
    umask 077
    cat > "$dest" << EOF
# =============================================================================
# secrets.conf — généré par l'install $(date -Iseconds)
# =============================================================================
UBUNTU_PRO_TOKEN="${UBUNTU_PRO_TOKEN:-}"
WATCHDOG_MAIL="${WATCHDOG_MAIL:-}"
EOF
    chmod 600 "$dest"
    umask "${old_umask}"
    success "Options enregistrées dans ${dest} (chmod 600)"
}
