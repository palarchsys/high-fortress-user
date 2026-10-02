#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/ssh/configure.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/ssh/configure.sh
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

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"

require_root
detect_ssh_port

title "Configuration SSH (drop-in)"
info "Port détecté : ${SSH_PORT} (conservé)"
backup_file_once /etc/ssh/sshd_config

ensure_dir /etc/ssh/sshd_config.d 755
# 00- est lu avant 50-cloud-init.conf. La première valeur gagne.
install -m 644 "${DIR_SCRIPT_PATH}/00-high-fortress-user.conf" /etc/ssh/sshd_config.d/00-high-fortress-user.conf
rm -f /etc/ssh/sshd_config.d/99-high-fortress-user.conf

# Une ligne PermitRootLogin placée avant « Include ... sshd_config.d »
# est lue en premier et masque le drop-in. On la commente.
# Même traitement pour les autres snippets, afin que 00- soit la seule source.
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
    # Une valeur lue avant le drop-in gagne. Un bloc Match all en fin de
    # fichier s'applique à toutes les connexions et remplace cette valeur.
    if ! grep -q 'High-Fortress User permit-root' /etc/ssh/sshd_config; then
        cat >> /etc/ssh/sshd_config << 'EOF'

# High-Fortress User permit-root
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

info "Test de syntaxe sshd..."
if ! sshd -t; then
    error "sshd -t a échoué — drop-in retiré"
fi
root_login="$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2; exit}')"
if [[ "${root_login}" != "no" ]]; then
    error "PermitRootLogin effectif : ${root_login:-inconnu}. Attendu : no."
fi

info "Service SSH en daemon (pas seulement socket-activation, Lynis SSH-*)..."
try_silent systemctl disable --now ssh.socket
try_silent systemctl unmask "${SSH_SERVICE_NAME}.service"
run_silent systemctl enable --now "${SSH_SERVICE_NAME}.service"
run_silent systemctl reload-or-restart "${SSH_SERVICE_NAME}"
success "SSH durci (PermitRootLogin no, PasswordAuthentication conservé, port ${SSH_PORT})"
