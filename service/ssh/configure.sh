#!/usr/bin/env bash
# =============================================================================
# File       : service/ssh/configure.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"

require_root
detect_ssh_port

title "Configuration SSH (drop-in)"
info "Port détecté : ${SSH_PORT} (conservé)"
info "Configuration de SSH"
backup_file_once /etc/ssh/sshd_config

ensure_dir /etc/ssh/sshd_config.d 755

install -m 644 "${DIR_SCRIPT_PATH}/00-high-fortress-user.conf" /etc/ssh/sshd_config.d/00-high-fortress-user.conf
rm -f /etc/ssh/sshd_config.d/99-high-fortress-user.conf

if [[ -f /etc/ssh/sshd_config ]]; then
    awk '
        /^[[:space:]]*Include[[:space:]]/ && !seen { seen = 1 }
        !seen && /^[[:space:]]*PermitRootLogin[[:space:]]/ {
            print "# High-Fortress User : une définition plus bas impose PermitRootLogin no"
            print "# " $0
            next
        }
        { print }
    ' /etc/ssh/sshd_config > /etc/ssh/sshd_config.hfu \
        && cat /etc/ssh/sshd_config.hfu > /etc/ssh/sshd_config \
        && rm -f /etc/ssh/sshd_config.hfu

    if ! grep -q 'High-Fortress User permit-root' /etc/ssh/sshd_config; then
        cat >> /etc/ssh/sshd_config << 'EOF'

Match all
    PermitRootLogin no
EOF
    fi
fi
for snippet in /etc/ssh/sshd_config.d/*.conf; do
    [[ -f "${snippet}" ]] || continue
    [[ "${snippet}" == *00-high-fortress-user.conf ]] && continue
    if grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]' "${snippet}"; then
        sed -i 's/^[[:space:]]*PermitRootLogin[[:space:]].*/# High-Fortress User : le drop-in 00- pose PermitRootLogin no\n# &/' "${snippet}"
    fi
done

ensure_dir "$(dirname "${SSH_BANNER_PATH}")" 755
ensure_dir /run/sshd 755
printf '%s\n' "${BANNER_MESSAGE}" > "${SSH_BANNER_PATH}"
chmod 644 "${SSH_BANNER_PATH}"

info "Test de syntaxe sshd"
if ! sshd -t; then
    error "sshd -t a échoué — drop-in retiré"
fi
root_login="$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2; exit}')"
if [[ "${root_login}" != "no" ]]; then
    error "PermitRootLogin effectif : ${root_login:-inconnu}. Attendu : no."
fi

info "Passage de SSH en service (pas seulement l'activation par socket)"
try_silent systemctl disable --now ssh.socket
try_silent systemctl unmask "${SSH_SERVICE_NAME}.service"
run_silent systemctl enable --now "${SSH_SERVICE_NAME}.service"
run_silent systemctl reload-or-restart "${SSH_SERVICE_NAME}"
success "SSH durci (root interdit, mot de passe gardé, port ${SSH_PORT})"
