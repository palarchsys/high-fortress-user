#!/usr/bin/env bash
# =============================================================================
# File       : service/ssh/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"

g_require_root
g_get_ssh_port

g_log_title "Configuration SSH (drop-in)"
g_log_info "Port détecté : ${SSH_PORT}"
g_log_info "Configuration de SSH"
g_copy_backup /etc/ssh/sshd_config

g_ensure_directory /etc/ssh/sshd_config.d 755

install -m 644 "$(g_locate_config_file ssh/00-liltress-workstation.conf)" /etc/ssh/sshd_config.d/00-liltress-workstation.conf
rm -f /etc/ssh/sshd_config.d/99-liltress-workstation.conf

if [[ -f /etc/ssh/sshd_config ]]; then
    awk '
        /^[[:space:]]*Include[[:space:]]/ && !seen { seen = 1 }
        !seen && /^[[:space:]]*PermitRootLogin[[:space:]]/ {
            print "# Liltress Workstation : une définition plus bas impose PermitRootLogin no"
            print "# " $0
            next
        }
        { print }
    ' /etc/ssh/sshd_config > /etc/ssh/sshd_config.hfu \
        && cat /etc/ssh/sshd_config.hfu > /etc/ssh/sshd_config \
        && rm -f /etc/ssh/sshd_config.hfu

    if ! grep -q 'Liltress Workstation permit-root' /etc/ssh/sshd_config \
        && ! grep -q 'High-Fortress User permit-root' /etc/ssh/sshd_config; then
        cat "$(g_locate_config_file ssh/permit-root.conf)" >> /etc/ssh/sshd_config
    fi
fi
for snippet in /etc/ssh/sshd_config.d/*.conf; do
    [[ -f "${snippet}" ]] || continue
    [[ "${snippet}" == *00-liltress-workstation.conf ]] && continue
    if grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]' "${snippet}"; then
        sed -i 's/^[[:space:]]*PermitRootLogin[[:space:]].*/# Liltress Workstation : le drop-in 00- pose PermitRootLogin no\n# &/' "${snippet}"
    fi
done

g_ensure_directory "$(dirname "${G_SSH_BANNER_PATH}")" 755
g_ensure_directory /run/sshd 755
printf '%s\n' "${G_BANNER_MESSAGE}" > "${G_SSH_BANNER_PATH}"
chmod 644 "${G_SSH_BANNER_PATH}"

g_log_info "Test de syntaxe sshd"
if ! sshd -t; then
    g_log_error "sshd -t a échoué — drop-in retiré"
fi
root_login="$(g_get_sshd_value permitrootlogin)"
if [[ "${root_login}" != "no" ]]; then
    g_log_error "PermitRootLogin effectif : ${root_login:-inconnu}. Attendu : no."
fi

g_log_info "Passage de SSH en service (pas seulement l'activation par socket)"
g_run_optional systemctl disable --now ssh.socket
g_run_optional systemctl unmask "${G_SSH_SERVICE_NAME}.service"
g_run_silent systemctl enable --now "${G_SSH_SERVICE_NAME}.service"
g_run_silent systemctl reload-or-restart "${G_SSH_SERVICE_NAME}"
g_log_success "SSH durci (root interdit, mot de passe gardé, port ${SSH_PORT})"
