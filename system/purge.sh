#!/usr/bin/env bash
# =============================================================================
# File       : system/purge.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"

require_root

purge_rc_packages() {

    title "Purge des paquets rc (Lynis PKGS-7346)"
    info "Contrôle des paquets rc"
    mapfile -t rc_all < <(dpkg -l 2>/dev/null | awk '/^rc/{print $2}')
    rc_pkgs=()
    local p
    for p in "${rc_all[@]}"; do
        case "${p}" in
            grub-pc|grub-pc-bin|grub-gfxpayload-lists) info "rc conservé (boot) : ${p}" ;;
            *) rc_pkgs+=("${p}") ;;
        esac
    done
    if [[ ${#rc_pkgs[@]} -gt 0 ]]; then
        info "Purge des paquets rc (${rc_pkgs[*]})"
        run_silent_apt purge -y "${rc_pkgs[@]}"
        success "Paquets rc purgés (${#rc_pkgs[@]})"
    else
        success "Aucun paquet rc à purger"
    fi
}

if [[ "${HF_PURGE_RC_ONLY:-0}" == "1" ]]; then
    purge_rc_packages
    exit 0
fi

if [[ "${HF_REAPPLY_LOCKS:-0}" == "1" ]]; then

    title "Réapplication des désactivations"
    info "Le dernier upgrade peut réactiver systemd-coredump."
else

purge_rc_packages

info "CUPS, bluetooth, avahi et compilateurs inchangés."
success "Purge workstation terminée"

fi

info "Masquage de systemd-coredump"
try_silent systemctl mask systemd-coredump.socket
success "systemd-coredump masqué"
