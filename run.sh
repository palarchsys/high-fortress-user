#!/usr/bin/env bash
# =============================================================================
# Fichier    : run.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   run.sh — installation du poste Ubuntu 26.04
# =============================================================================

# Point d'entrée root. Les questions sont posées par configure.sh.
# Ce script refuse de démarrer si global.conf et secrets.conf ne sont
# pas conformes (bash configure.sh --check).
#
# Ordre :
#   1. Snaps Firefox et Thunderbird seulement ; snapd reste
#   2. Réglages du poste, Postfix, SSH
#   3. Pile de sécurité, dont ClamAV en continu
#   4. Logiciels du bureau, puis leurs profils AppArmor
#   5. Purge des paquets résiduels, recette, base AIDE, e-mail
#
# Les comptes créés par l'installateur Ubuntu et les dépôts APT déjà
# présents ne sont pas modifiés.
# =============================================================================

# shellcheck disable=SC2155
DIR_INSTALL_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export DIR_INSTALL_PATH

# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/config-check.sh"
if ! hfu_require_prepared_config "${DIR_INSTALL_PATH}"; then
    printf '\nInstallation refusée. Préparez les deux fichiers :\n' >&2
    printf '  bash %s/configure.sh\n' "${DIR_INSTALL_PATH}" >&2
    printf '  bash %s/configure.sh --check\n' "${DIR_INSTALL_PATH}" >&2
    exit 1
fi
readonly DIR_INSTALL_PATH

clear

# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/global.conf"
# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/lib.sh"

require_root
detect_os
detect_current_user
detect_ssh_port
SERVER_TYPE="WORKSTATION"
export SERVER_TYPE

violet "═════════════════════════════════════════════════════════════════════════════════"
violet " High-Fortress User — durcissement workstation                                   "
violet "═════════════════════════════════════════════════════════════════════════════════"

title "Contrat (non négociable)"
echo "   Utilisateur courant : ${CURRENT_USER}  (home ${CURRENT_HOME})"
echo "   Port SSH détecté    : ${SSH_PORT}"
echo "   OS                  : ${OS_PRETTY}"
echo ""
echo "   • Comptes humains (uid, groupes, home, shell, mot de passe) : inchangés."
echo "   • Snaps Firefox et Thunderbird retirés. snapd reste installé."
echo "   • Postfix et SSH, puis la pile de sécurité."
echo "   • Ensuite : Brave, Thunderbird (Mozilla), KeePassXC,"
echo "     Discord et Vencord, puis les profils AppArmor de ces programmes."
echo "   • Steam et KeePassXC restent utilisables. Dépôts APT existants intacts."
echo "   • i386 activé sur amd64 (Steam)."
echo "   • UFW : deny incoming, ALLOW outgoing."
echo "   • SSH : drop-in, PasswordAuthentication conservé, PermitRootLogin no."
echo "   • Ubuntu Pro : ESM infra, ESM apps et Livepatch."
echo "   • AIDE : base de référence prise tout à la fin, sur le disque terminé."
echo ""

init_install_log
snapshot_human_accounts
trap collect_install_logs EXIT

# -----------------------------------------------------------------------------
# Étapes
# -----------------------------------------------------------------------------

STEP_SYSTEM_INSTALL=(
    "system/install.sh"
)
STEP_SYSTEM_CONFIGURE=("system/configure.sh")
STEP_SYSTEM_PURGE=("system/purge.sh")
STEP_SSH_CONFIGURE=("service/ssh/configure.sh")

STEP_SECURITY_INSTALL=(
    "service/ufw/install.sh"
    "service/fail2ban/install.sh"
    "service/auditd/install.sh"
    "service/rkhunter/install.sh"
    "service/chkrootkit/install.sh"
    "service/clamav/install.sh"
    "service/crowdsec/install.sh"
    "service/debsums/install.sh"
    "service/apparmor/install.sh"
    "service/aide/install.sh"
    "service/unattended-upgrades/install.sh"
)

STEP_SECURITY_CONFIGURE=(
    "service/ufw/configure.sh"
    "service/fail2ban/configure.sh"
    "service/auditd/configure.sh"
    "service/rkhunter/configure.sh"
    "service/clamav/configure.sh"
    "service/crowdsec/configure.sh"
    "service/apparmor/configure.sh"
    "service/aide/configure.sh"
    "service/unattended-upgrades/configure.sh"
    "service/cron/configure.sh"
)

# 1. Firefox et Thunderbird quittent Snap. snapd et les autres snaps restent.
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "system/snap-remove.sh"
# 2. Base du poste, avant la surveillance continue.
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SYSTEM_INSTALL[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SYSTEM_CONFIGURE[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "service/postfix/install.sh"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "service/postfix/configure.sh"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SSH_CONFIGURE[@]}"
# 3. Pile de sécurité. ClamAV surveille /tmp à partir d'ici.
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SECURITY_INSTALL[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SECURITY_CONFIGURE[@]}"
# 4. Logiciels du bureau. Les profils userns visent ces binaires.
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "service/desktop/install.sh"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "service/apparmor/userns.sh"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SYSTEM_PURGE[@]}"

try_silent sysctl --system

# Lynis retire 25 points (PKGS-7392) tant qu'apt-check voit un
# correctif de sécurité. On les installe avant l'audit, y compris
# ceux encore en déploiement progressif.
title "Correctifs de sécurité"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
run_silent_apt update
run_silent_apt -o APT::Get::Always-Include-Phased-Updates=true upgrade -y --with-new-pkgs
success "Correctifs de sécurité installés"

run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "verify/workstation.sh"

# Dernière écriture de l'installation. Brave, Thunderbird,
# les profils AppArmor, les scripts de contrôle et la purge sont
# déjà sur le disque. La recette n'écrit que des journaux dans
# /var/log, hors du périmètre AIDE. L'e-mail de test part ensuite.
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "service/aide/init-db.sh"

title "E-mail de test"
if [[ -z "${WATCHDOG_MAIL:-}" ]]; then
    error "WATCHDOG_MAIL est vide : l'e-mail de fin d'installation ne peut pas partir."
fi
export TITLE="Installation terminée"
export MODULE_NAME="Installation"
export PROJECT_NAME
export WATCHDOG_MAIL
export CONTENT="Ceci est un message de test.

L'installation de ${PROJECT_NAME} s'est terminée correctement.
Cet e-mail vérifie que Postfix peut joindre ${WATCHDOG_MAIL}."
if ! bash "${DIR_INSTALL_PATH}/service/cron/watchdogs/send.sh"; then
    error "L'e-mail de test vers ${WATCHDOG_MAIL} n'a pas été accepté par Postfix."
fi
success "E-mail de test envoyé à ${WATCHDOG_MAIL}"

step_off "Installation terminée"

info "Utilisateur intact : ${CURRENT_USER} (mot de passe non modifié)"
info "Journaux          : ${HF_LOG_DIR}"
info "Audit Lynis       : sudo bash ${DIR_INSTALL_PATH}/lynis.sh"
echo ""
reboot_needed=0
[[ -f /var/run/reboot-required ]] && reboot_needed=1
if command -v needrestart >/dev/null 2>&1; then
    nr_out="$(needrestart -b -r l 2>/dev/null || true)"
    if printf '%s\n' "${nr_out}" | grep -qE '^NEEDRESTART-KSTA: [2-9]|^NEEDRESTART-SVC:|^NEEDRESTART-SESS:'; then
        reboot_needed=1
    fi
fi
if [[ "${reboot_needed}" -eq 1 ]]; then
    info "Un reboot est recommandé (noyau / libc)."
fi
echo ""
