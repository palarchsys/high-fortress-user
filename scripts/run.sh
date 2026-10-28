#!/usr/bin/env bash
# =============================================================================
# File       : scripts/run.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

# shellcheck disable=SC2155

G_INSTALL_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
export G_INSTALL_DIRECTORY

# shellcheck disable=SC1091
source "${G_INSTALL_DIRECTORY}/scripts/config-check.sh"
if ! w_require_prepared_config "${G_INSTALL_DIRECTORY}"; then
    printf '\nInstallation refusée. Préparez les deux fichiers :\n' >&2
    printf '  bash %s/liltress configure\n' "${G_INSTALL_DIRECTORY}" >&2
    printf '  bash %s/liltress check\n' "${G_INSTALL_DIRECTORY}" >&2
    exit 1
fi
readonly G_INSTALL_DIRECTORY

clear

# shellcheck disable=SC1091
source "${G_INSTALL_DIRECTORY}/config/global.conf"
# shellcheck disable=SC1091
source "${G_INSTALL_DIRECTORY}/core/lib.sh"

g_require_root
chmod 755 "${G_INSTALL_DIRECTORY}/liltress"
g_get_operating_system
g_get_current_user
g_get_ssh_port

g_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"
g_set_color_violet " Liltress Workstation — durcissement workstation                                   "
g_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"

g_log_title "Poste"
echo "   Utilisateur courant : ${CURRENT_USER}  (home ${CURRENT_HOME})"
echo "   Port SSH détecté    : ${SSH_PORT}"
echo "   OS                  : ${OS_PRETTY}"
echo ""
echo "   • SSH, puis la pile de sécurité. Postfix suit le choix des alertes e-mail."
echo "   • Après les correctifs : USBGuard."
echo "   • i386 activé sur amd64."
echo "   • UFW : deny incoming, allow outgoing."
echo "   • DNS : Unbound local."
echo "   • SSH : PasswordAuthentication yes, PermitRootLogin no."
echo "   • Ubuntu Pro : ESM infra, ESM apps et Livepatch."
echo "   • AIDE : base de référence, puis verify/workstation.sh."
echo ""

g_init_install_log
g_record_account_snapshot
trap g_install_exit EXIT

STEP_SYSTEM_INSTALL=(
    "system/install.sh"
)
STEP_SYSTEM_CONFIGURE=("system/configure.sh")
STEP_SYSTEM_PURGE=("system/purge.sh")
STEP_SSH_CONFIGURE=("service/ssh/configure.sh")

STEP_SECURITY_INSTALL=(
    "service/ufw/install.sh"
    "service/usbguard/install.sh"
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

g_run_step "${G_INSTALL_DIRECTORY}" "system/snapd.sh"
g_run_step "${G_INSTALL_DIRECTORY}" "${STEP_SYSTEM_PURGE[@]}"

g_run_step "${G_INSTALL_DIRECTORY}" "${STEP_SYSTEM_INSTALL[@]}"
g_run_step "${G_INSTALL_DIRECTORY}" "${STEP_SYSTEM_CONFIGURE[@]}"
if [[ "${G_MAIL_ALERTS:-0}" == "1" ]]; then
    g_run_step "${G_INSTALL_DIRECTORY}" "service/postfix/install.sh"
    g_run_step "${G_INSTALL_DIRECTORY}" "service/postfix/configure.sh"
fi
if [[ "${G_RCLONE_ALERTS:-0}" == "1" ]]; then
    g_run_step "${G_INSTALL_DIRECTORY}" "service/rclone/install.sh"
fi
g_run_step "${G_INSTALL_DIRECTORY}" "${STEP_SSH_CONFIGURE[@]}"

g_run_step "${G_INSTALL_DIRECTORY}" "${STEP_SECURITY_INSTALL[@]}"
g_run_step "${G_INSTALL_DIRECTORY}" "${STEP_SECURITY_CONFIGURE[@]}"

g_run_step "${G_INSTALL_DIRECTORY}" "service/apparmor/userns.sh"

g_run_optional sysctl --system

g_log_title "Correctifs de sécurité"
g_log_info "Installation des correctifs de sécurité"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
g_run_silent_apt update
g_run_silent_apt -o APT::Get::Always-Include-Phased-Updates=true upgrade -y --with-new-pkgs
g_log_success "Correctifs de sécurité installés"

g_run_step "${G_INSTALL_DIRECTORY}" "service/usbguard/configure.sh"

G_PURGE_REMOVED_CONFIG_ONLY=1 bash "${G_INSTALL_DIRECTORY}/system/purge.sh" "${G_INSTALL_DIRECTORY}"

G_REAPPLY_LOCKS=1 bash "${G_INSTALL_DIRECTORY}/system/purge.sh" "${G_INSTALL_DIRECTORY}"
g_run_step "${G_INSTALL_DIRECTORY}" "service/rkhunter/init-db.sh"

g_run_step "${G_INSTALL_DIRECTORY}" "service/aide/init-db.sh"

g_run_step "${G_INSTALL_DIRECTORY}" "verify/workstation.sh"

if [[ "${G_MAIL_ALERTS:-0}" == "1" ]]; then

    g_log_title "E-mail de test"
    if [[ -z "${G_WATCHDOG_MAIL:-}" ]]; then
        g_log_error "G_WATCHDOG_MAIL est vide : l'e-mail de fin d'installation ne peut pas partir."
    fi
    g_log_info "Envoi de l'e-mail de test à ${G_WATCHDOG_MAIL}"
    export TITLE="Installation terminée"
    export MODULE_NAME="Installation"
    export G_PROJECT_NAME
    export G_WATCHDOG_MAIL
    export CONTENT="Ceci est un message de test.

L'installation de ${G_PROJECT_NAME} s'est terminée correctement.
Cet e-mail vérifie que Postfix peut joindre ${G_WATCHDOG_MAIL}."
    if ! bash "${G_INSTALL_DIRECTORY}/service/cron/watchdogs/send.sh"; then
        g_log_error "L'e-mail de test vers ${G_WATCHDOG_MAIL} n'a pas été accepté par Postfix."
    fi
    g_log_success "E-mail de test envoyé à ${G_WATCHDOG_MAIL}"
else
    g_log_info "Alertes e-mail coupées : aucun message de fin n'est envoyé."
fi

g_set_step_hidden "Installation terminée"

g_log_info "Journaux : ${G_LOG_DIR}"
g_log_info "Lynis : sudo bash liltress lynis"
reboot_needed=0
[[ -f /var/run/reboot-required ]] && reboot_needed=1
if command -v needrestart >/dev/null 2>&1; then
    nr_out="$(needrestart -b -r l 2>/dev/null || true)"
    if printf '%s\n' "${nr_out}" | grep -qE '^NEEDRESTART-KSTA: [2-9]|^NEEDRESTART-SVC:|^NEEDRESTART-SESS:'; then
        reboot_needed=1
    fi
fi
if [[ "${reboot_needed}" -eq 1 ]]; then
    g_log_info "Un reboot est recommandé (noyau / libc)."
fi
g_offer_remove_installer
