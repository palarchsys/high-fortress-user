#!/usr/bin/env bash
# =============================================================================
# File       : system/purge.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"

hf_require_root

hfu_remove_cups() {

    local p unit
    local -a cups_pkgs=()
    hf_log_title "CUPS"
    for p in cups cups-daemon cups-browsed cups-core-drivers cups-server-common cups-filters; do
        if dpkg-query -W -f '${Status}\n' "${p}" 2>/dev/null | grep -q 'install ok'; then
            cups_pkgs+=("${p}")
        fi
    done
    if dpkg-statoverride --list /etc/cups/cupsd.conf >/dev/null 2>&1; then
        dpkg-statoverride --remove /etc/cups/cupsd.conf >/dev/null 2>&1 || true
    fi
    if [[ ${#cups_pkgs[@]} -gt 0 ]]; then
        hf_log_info "Purge de CUPS (${cups_pkgs[*]})"
        for unit in cups.socket cups.path cups-browsed.socket cups-browsed.service cups.service; do
            timeout 20 systemctl disable --now "${unit}" >/dev/null 2>&1 || true
            timeout 20 systemctl stop "${unit}" >/dev/null 2>&1 || true
            systemctl kill "${unit}" >/dev/null 2>&1 || true
        done
        hf_run_silent_apt purge -y "${cups_pkgs[@]}"
        hf_log_success "CUPS purgé"
    else
        hf_log_info "Contrôle de CUPS"
        hf_log_success "CUPS absent"
    fi
}

hfu_remove_removed_config_package() {

    hf_log_title "Purge des paquets rc (Lynis PKGS-7346)"
    hf_log_info "Contrôle des paquets rc"
    mapfile -t rc_all < <(dpkg -l 2>/dev/null | awk '/^rc/{print $2}')
    rc_pkgs=()
    local p
    for p in "${rc_all[@]}"; do
        case "${p}" in
            grub-pc|grub-pc-bin|grub-gfxpayload-lists) hf_log_info "rc conservé (boot) : ${p}" ;;
            *) rc_pkgs+=("${p}") ;;
        esac
    done
    if [[ ${#rc_pkgs[@]} -gt 0 ]]; then
        hf_log_info "Purge des paquets rc (${rc_pkgs[*]})"
        hf_run_silent_apt purge -y "${rc_pkgs[@]}"
        hf_log_success "Paquets rc purgés (${#rc_pkgs[@]})"
    else
        hf_log_success "Aucun paquet rc à purger"
    fi
}

if [[ "${HF_PURGE_REMOVED_CONFIG_ONLY:-0}" == "1" ]]; then
    hfu_remove_removed_config_package
    exit 0
fi

if [[ "${HF_REAPPLY_LOCKS:-0}" == "1" ]]; then

    hf_log_title "Réapplication des désactivations"
    hf_log_info "Le dernier upgrade peut réactiver systemd-coredump."
else

hfu_remove_cups

hfu_remove_removed_config_package

hf_log_success "Purge workstation terminée"

fi

hf_log_info "Masquage de systemd-coredump"
hf_run_optional systemctl mask systemd-coredump.socket
hf_log_success "systemd-coredump masqué"
