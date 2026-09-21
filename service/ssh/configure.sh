#!/usr/bin/env bash
# =============================================================================
# service/ssh/configure.sh
# =============================================================================
# Rôle       : Drop-in sshd_config.d — durcit sans changer le port ni couper
#              l'auth mot de passe. Aucune clé forcée, aucun AllowUsers.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"

require_root
detect_ssh_port

title "Configuration SSH (drop-in)"
info "Port détecté : ${SSH_PORT} (conservé)"
backup_file_once /etc/ssh/sshd_config

ensure_dir /etc/ssh/sshd_config.d 755
install -m 644 "${DIR_SCRIPT_PATH}/99-high-fortress-user.conf" /etc/ssh/sshd_config.d/99-high-fortress-user.conf

ensure_dir "$(dirname "${SSH_BANNER_PATH}")" 755
ensure_dir /run/sshd 755
printf '%s\n' "${BANNER_MESSAGE}" > "${SSH_BANNER_PATH}"
chmod 644 "${SSH_BANNER_PATH}"

info "Test de syntaxe sshd..."
if ! sshd -t; then
    error "sshd -t a échoué — drop-in retiré"
fi

info "Service SSH en daemon (pas seulement socket-activation, Lynis SSH-*)..."
try_silent systemctl disable --now ssh.socket
try_silent systemctl unmask "${SSH_SERVICE_NAME}.service"
run_silent systemctl enable --now "${SSH_SERVICE_NAME}.service"
run_silent systemctl reload-or-restart "${SSH_SERVICE_NAME}"
success "SSH durci (PermitRootLogin no, PasswordAuthentication conservé, port ${SSH_PORT})"
