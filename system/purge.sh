#!/usr/bin/env bash
# =============================================================================
# File       : system/purge.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"

g_require_root

w_remove_cups() {

    local p unit
    local -a cups_pkgs=()
    g_log_title "CUPS"
    for p in cups cups-daemon cups-browsed cups-core-drivers cups-server-common cups-filters; do
        if dpkg-query -W -f '${Status}\n' "${p}" 2>/dev/null | grep -q 'install ok'; then
            cups_pkgs+=("${p}")
        fi
    done
    if dpkg-statoverride --list /etc/cups/cupsd.conf >/dev/null 2>&1; then
        dpkg-statoverride --remove /etc/cups/cupsd.conf >/dev/null 2>&1 || true
    fi
    if [[ ${#cups_pkgs[@]} -gt 0 ]]; then
        g_log_info "Purge de CUPS (${cups_pkgs[*]})"
        for unit in cups.socket cups.path cups-browsed.socket cups-browsed.service cups.service; do
            timeout 20 systemctl disable --now "${unit}" >/dev/null 2>&1 || true
            timeout 20 systemctl stop "${unit}" >/dev/null 2>&1 || true
            systemctl kill "${unit}" >/dev/null 2>&1 || true
        done
        g_run_silent_apt purge -y "${cups_pkgs[@]}"
        g_log_success "CUPS purgé"
    else
        g_log_info "Contrôle de CUPS"
        g_log_success "CUPS absent"
    fi
}

w_remove_removed_config_package() {

    g_log_title "Purge des paquets rc (Lynis PKGS-7346)"
    g_log_info "Contrôle des paquets rc"
    mapfile -t rc_all < <(dpkg -l 2>/dev/null | awk '/^rc/{print $2}')
    rc_pkgs=()
    local p
    for p in "${rc_all[@]}"; do
        case "${p}" in
            grub-pc|grub-pc-bin|grub-gfxpayload-lists) g_log_info "rc conservé (boot) : ${p}" ;;
            *) rc_pkgs+=("${p}") ;;
        esac
    done
    if [[ ${#rc_pkgs[@]} -gt 0 ]]; then
        g_log_info "Purge des paquets rc (${rc_pkgs[*]})"
        g_run_silent_apt purge -y "${rc_pkgs[@]}"
        g_log_success "Paquets rc purgés (${#rc_pkgs[@]})"
    else
        g_log_success "Aucun paquet rc à purger"
    fi
}

if [[ "${G_PURGE_REMOVED_CONFIG_ONLY:-0}" == "1" ]]; then
    w_remove_removed_config_package
    exit 0
fi

if [[ "${G_REAPPLY_LOCKS:-0}" == "1" ]]; then

    g_log_title "Réapplication des désactivations"
    g_log_info "Le dernier upgrade peut réactiver systemd-coredump."
else

w_remove_cups

w_remove_removed_config_package

g_log_success "Purge workstation terminée"

fi

g_log_info "Masquage de systemd-coredump"
g_run_optional systemctl mask systemd-coredump.socket
g_log_success "systemd-coredump masqué"
