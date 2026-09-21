#!/usr/bin/env bash
# =============================================================================
# run.sh — orchestrateur High-Fortress User (workstation Ubuntu 26.04)
# =============================================================================
# Point d'entrée unique (root). Ne change jamais les mots de passe.
# Ne casse pas Firefox, Steam, Discord, Telegram, APT, KVM/QEMU.
# =============================================================================

clear

# shellcheck disable=SC2155
readonly DIR_INSTALL_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/global.conf"
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
echo "   • Aucun mot de passe (root / ${CURRENT_USER}) ne sera modifié."
echo "   • Firefox, Steam, Discord, Telegram, dépôts APT, KVM/QEMU : préservés."
echo "   • UFW : deny incoming, ALLOW outgoing (Steam / Discord / Telegram / apt)."
echo "   • SSH : drop-in, PasswordAuthentication conservé, PermitRootLogin no."
echo "   • Ubuntu Pro : obligatoire (ESM infra/apps + livepatch)."
echo ""

prompt_and_save_secrets
init_install_log
trap collect_install_logs EXIT

# -----------------------------------------------------------------------------
# Étapes
# -----------------------------------------------------------------------------

STEP_SYSTEM_INSTALL=("system/install.sh")
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
    "service/apparmor/configure.sh"
    "service/aide/configure.sh"
    "service/unattended-upgrades/configure.sh"
    "service/cron/configure.sh"
)

run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SYSTEM_INSTALL[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SYSTEM_CONFIGURE[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SSH_CONFIGURE[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SECURITY_INSTALL[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SECURITY_CONFIGURE[@]}"
run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "${STEP_SYSTEM_PURGE[@]}"

try_silent sysctl --system

run_steps "${DIR_INSTALL_PATH}" "${SERVER_TYPE}" "verify/workstation.sh"

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
