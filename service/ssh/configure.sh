#!/usr/bin/env bash
# =============================================================================
# File       : service/ssh/configure.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"

hf_require_root
hf_get_ssh_port

hf_log_title "Configuration SSH (drop-in)"
hf_log_info "Port détecté : ${SSH_PORT}"
hf_log_info "Configuration de SSH"
hf_copy_backup /etc/ssh/sshd_config

hf_ensure_directory /etc/ssh/sshd_config.d 755

install -m 644 "$(hf_locate_config_file ssh/00-high-fortress-user.conf)" /etc/ssh/sshd_config.d/00-high-fortress-user.conf
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
        cat "$(hf_locate_config_file ssh/permit-root.conf)" >> /etc/ssh/sshd_config
    fi
fi
for snippet in /etc/ssh/sshd_config.d/*.conf; do
    [[ -f "${snippet}" ]] || continue
    [[ "${snippet}" == *00-high-fortress-user.conf ]] && continue
    if grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]' "${snippet}"; then
        sed -i 's/^[[:space:]]*PermitRootLogin[[:space:]].*/# High-Fortress User : le drop-in 00- pose PermitRootLogin no\n# &/' "${snippet}"
    fi
done

hf_ensure_directory "$(dirname "${HF_SSH_BANNER_PATH}")" 755
hf_ensure_directory /run/sshd 755
printf '%s\n' "${HF_BANNER_MESSAGE}" > "${HF_SSH_BANNER_PATH}"
chmod 644 "${HF_SSH_BANNER_PATH}"

hf_log_info "Test de syntaxe sshd"
if ! sshd -t; then
    hf_log_error "sshd -t a échoué — drop-in retiré"
fi
root_login="$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2; exit}')"
if [[ "${root_login}" != "no" ]]; then
    hf_log_error "PermitRootLogin effectif : ${root_login:-inconnu}. Attendu : no."
fi

hf_log_info "Passage de SSH en service (pas seulement l'activation par socket)"
hf_run_optional systemctl disable --now ssh.socket
hf_run_optional systemctl unmask "${HF_SSH_SERVICE_NAME}.service"
hf_run_silent systemctl enable --now "${HF_SSH_SERVICE_NAME}.service"
hf_run_silent systemctl reload-or-restart "${HF_SSH_SERVICE_NAME}"
hf_log_success "SSH durci (root interdit, mot de passe gardé, port ${SSH_PORT})"
