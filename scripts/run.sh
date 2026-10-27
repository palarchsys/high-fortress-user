#!/usr/bin/env bash
# =============================================================================
# File       : scripts/run.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

# shellcheck disable=SC2155

HF_INSTALL_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
export HF_INSTALL_DIRECTORY

# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/scripts/config-check.sh"
if ! hfu_require_prepared_config "${HF_INSTALL_DIRECTORY}"; then
    printf '\nInstallation refusée. Préparez les deux fichiers :\n' >&2
    printf '  bash %s/hf configure\n' "${HF_INSTALL_DIRECTORY}" >&2
    printf '  bash %s/hf check\n' "${HF_INSTALL_DIRECTORY}" >&2
    exit 1
fi
readonly HF_INSTALL_DIRECTORY

clear

# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"

hf_require_root
chmod 755 "${HF_INSTALL_DIRECTORY}/hf"
hf_get_operating_system
hf_get_current_user
hf_get_ssh_port

hf_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"
hf_set_color_violet " High-Fortress User — durcissement workstation                                   "
hf_set_color_violet "═════════════════════════════════════════════════════════════════════════════════"

hf_log_title "Poste"
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

hf_init_install_log
hf_record_account_snapshot
trap hf_install_exit EXIT

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

hf_run_step "${HF_INSTALL_DIRECTORY}" "system/snapd.sh"
hf_run_step "${HF_INSTALL_DIRECTORY}" "${STEP_SYSTEM_PURGE[@]}"

hf_run_step "${HF_INSTALL_DIRECTORY}" "${STEP_SYSTEM_INSTALL[@]}"
hf_run_step "${HF_INSTALL_DIRECTORY}" "${STEP_SYSTEM_CONFIGURE[@]}"
if [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then
    hf_run_step "${HF_INSTALL_DIRECTORY}" "service/postfix/install.sh"
    hf_run_step "${HF_INSTALL_DIRECTORY}" "service/postfix/configure.sh"
fi
if [[ "${HF_RCLONE_ALERTS:-0}" == "1" ]]; then
    hf_run_step "${HF_INSTALL_DIRECTORY}" "service/rclone/install.sh"
fi
hf_run_step "${HF_INSTALL_DIRECTORY}" "${STEP_SSH_CONFIGURE[@]}"

hf_run_step "${HF_INSTALL_DIRECTORY}" "${STEP_SECURITY_INSTALL[@]}"
hf_run_step "${HF_INSTALL_DIRECTORY}" "${STEP_SECURITY_CONFIGURE[@]}"

hf_run_step "${HF_INSTALL_DIRECTORY}" "service/apparmor/userns.sh"

hf_run_optional sysctl --system

hf_log_title "Correctifs de sécurité"
hf_log_info "Installation des correctifs de sécurité"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
hf_run_silent_apt update
hf_run_silent_apt -o APT::Get::Always-Include-Phased-Updates=true upgrade -y --with-new-pkgs
hf_log_success "Correctifs de sécurité installés"

hf_run_step "${HF_INSTALL_DIRECTORY}" "service/usbguard/configure.sh"

HF_PURGE_REMOVED_CONFIG_ONLY=1 bash "${HF_INSTALL_DIRECTORY}/system/purge.sh" "${HF_INSTALL_DIRECTORY}"

HF_REAPPLY_LOCKS=1 bash "${HF_INSTALL_DIRECTORY}/system/purge.sh" "${HF_INSTALL_DIRECTORY}"
hf_run_step "${HF_INSTALL_DIRECTORY}" "service/rkhunter/init-db.sh"

hf_run_step "${HF_INSTALL_DIRECTORY}" "service/aide/init-db.sh"

hf_run_step "${HF_INSTALL_DIRECTORY}" "verify/workstation.sh"

if [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then

    hf_log_title "E-mail de test"
    if [[ -z "${HF_WATCHDOG_MAIL:-}" ]]; then
        hf_log_error "HF_WATCHDOG_MAIL est vide : l'e-mail de fin d'installation ne peut pas partir."
    fi
    hf_log_info "Envoi de l'e-mail de test à ${HF_WATCHDOG_MAIL}"
    export TITLE="Installation terminée"
    export MODULE_NAME="Installation"
    export HF_PROJECT_NAME
    export HF_WATCHDOG_MAIL
    export CONTENT="Ceci est un message de test.

L'installation de ${HF_PROJECT_NAME} s'est terminée correctement.
Cet e-mail vérifie que Postfix peut joindre ${HF_WATCHDOG_MAIL}."
    if ! bash "${HF_INSTALL_DIRECTORY}/service/cron/watchdogs/send.sh"; then
        hf_log_error "L'e-mail de test vers ${HF_WATCHDOG_MAIL} n'a pas été accepté par Postfix."
    fi
    hf_log_success "E-mail de test envoyé à ${HF_WATCHDOG_MAIL}"
else
    hf_log_info "Alertes e-mail coupées : aucun message de fin n'est envoyé."
fi

hf_set_step_hidden "Installation terminée"

hf_log_info "Journaux : ${HF_LOG_DIR}"
hf_log_info "Lynis : sudo bash hf lynis"
reboot_needed=0
[[ -f /var/run/reboot-required ]] && reboot_needed=1
if command -v needrestart >/dev/null 2>&1; then
    nr_out="$(needrestart -b -r l 2>/dev/null || true)"
    if printf '%s\n' "${nr_out}" | grep -qE '^NEEDRESTART-KSTA: [2-9]|^NEEDRESTART-SVC:|^NEEDRESTART-SESS:'; then
        reboot_needed=1
    fi
fi
if [[ "${reboot_needed}" -eq 1 ]]; then
    hf_log_info "Un reboot est recommandé (noyau / libc)."
fi
hf_offer_remove_installer
