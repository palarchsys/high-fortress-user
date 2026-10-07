#!/usr/bin/env bash
# =============================================================================
# File       : scripts/run.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

# shellcheck disable=SC2155

DIR_INSTALL_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
export DIR_INSTALL_PATH

# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/scripts/config-check.sh"
if ! hfu_require_prepared_config "${DIR_INSTALL_PATH}"; then
    printf '\nInstallation refusée. Préparez les deux fichiers :\n' >&2
    printf '  bash %s/hf configure\n' "${DIR_INSTALL_PATH}" >&2
    printf '  bash %s/hf check\n' "${DIR_INSTALL_PATH}" >&2
    exit 1
fi
readonly DIR_INSTALL_PATH

clear

# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/config/global.conf"
# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/core/lib.sh"

require_root
chmod 755 "${DIR_INSTALL_PATH}/hf"
detect_os
detect_current_user
detect_ssh_port

violet "═════════════════════════════════════════════════════════════════════════════════"
violet " High-Fortress User — durcissement workstation                                   "
violet "═════════════════════════════════════════════════════════════════════════════════"

title "Nouvelles règles"
echo "   Utilisateur courant : ${CURRENT_USER}  (home ${CURRENT_HOME})"
echo "   Port SSH détecté    : ${SSH_PORT}"
echo "   OS                  : ${OS_PRETTY}"
echo ""
echo "   • Comptes humains (uid, groupes, home, shell, mot de passe) : inchangés."
echo "   • Snaps Firefox et Thunderbird retirés. snapd reste installé."
echo "   • SSH, puis la pile de sécurité. Postfix suit le choix des alertes e-mail."
echo "   • Ensuite : Brave, Thunderbird (Mozilla), KeePassXC,"
echo "     Discord et Vencord, puis les profils AppArmor de ces programmes."
echo "   • Steam et KeePassXC restent utilisables. Dépôts APT existants intacts."
echo "   • i386 activé sur amd64 (Steam)."
echo "   • UFW : deny incoming, ALLOW outgoing."
echo "   • DNS : Unbound local, sans le résolveur du FAI."
echo "   • SSH : drop-in, PasswordAuthentication conservé, PermitRootLogin no."
echo "   • Ubuntu Pro : ESM infra, ESM apps et Livepatch."
echo "   • AIDE : base de référence prise tout à la fin, sur le disque terminé."
echo ""

init_install_log
snapshot_human_accounts
trap hf_install_exit EXIT

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
    "service/unbound/install.sh"
    "service/apparmor/install.sh"
    "service/aide/install.sh"
    "service/unattended-upgrades/install.sh"
)

STEP_SECURITY_CONFIGURE=(
    "service/ufw/configure.sh"
    "service/unbound/configure.sh"
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

run_steps "${DIR_INSTALL_PATH}" "system/snap-remove.sh"
run_steps "${DIR_INSTALL_PATH}" "${STEP_SYSTEM_PURGE[@]}"

run_steps "${DIR_INSTALL_PATH}" "${STEP_SYSTEM_INSTALL[@]}"
run_steps "${DIR_INSTALL_PATH}" "${STEP_SYSTEM_CONFIGURE[@]}"
if [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then
    run_steps "${DIR_INSTALL_PATH}" "service/postfix/install.sh"
    run_steps "${DIR_INSTALL_PATH}" "service/postfix/configure.sh"
fi
run_steps "${DIR_INSTALL_PATH}" "${STEP_SSH_CONFIGURE[@]}"

run_steps "${DIR_INSTALL_PATH}" "${STEP_SECURITY_INSTALL[@]}"
run_steps "${DIR_INSTALL_PATH}" "${STEP_SECURITY_CONFIGURE[@]}"

run_steps "${DIR_INSTALL_PATH}" "service/desktop/install.sh"
run_steps "${DIR_INSTALL_PATH}" "service/apparmor/userns.sh"

try_silent sysctl --system

title "Correctifs de sécurité"
info "Installation des correctifs de sécurité"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
run_silent_apt update
run_silent_apt -o APT::Get::Always-Include-Phased-Updates=true upgrade -y --with-new-pkgs
success "Correctifs de sécurité installés"

HF_PURGE_RC_ONLY=1 bash "${DIR_INSTALL_PATH}/system/purge.sh" "${DIR_INSTALL_PATH}"

HF_REAPPLY_LOCKS=1 bash "${DIR_INSTALL_PATH}/system/purge.sh" "${DIR_INSTALL_PATH}"
run_steps "${DIR_INSTALL_PATH}" "service/rkhunter/init-db.sh"

run_steps "${DIR_INSTALL_PATH}" "verify/workstation.sh"

run_steps "${DIR_INSTALL_PATH}" "service/aide/init-db.sh"

if [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then

    title "E-mail de test"
    if [[ -z "${WATCHDOG_MAIL:-}" ]]; then
        error "WATCHDOG_MAIL est vide : l'e-mail de fin d'installation ne peut pas partir."
    fi
    info "Envoi de l'e-mail de test à ${WATCHDOG_MAIL}"
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
else
    info "Alertes e-mail coupées : aucun message de fin n'est envoyé."
fi

step_off "Installation terminée"

info "${CURRENT_USER} : mot de passe inchangé"
info "Journaux : ${HF_LOG_DIR}"
info "Lynis : sudo bash hf lynis"
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
hf_offer_remove_installer
