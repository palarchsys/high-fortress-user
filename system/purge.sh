#!/usr/bin/env bash
# =============================================================================
# Fichier    : system/purge.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   system/purge.sh
# =============================================================================

# Rôle       : Réduit la surface (paquets rc uniquement).
#              NE PURGE PAS CUPS / bluetooth / avahi.
#              NE RESTREINT PAS les compilateurs.
#              Ne mask PAS rescue / getty.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"

require_root

title "Purge des paquets rc (Lynis PKGS-7346)"
mapfile -t rc_all < <(dpkg -l 2>/dev/null | awk '/^rc/{print $2}')
rc_pkgs=()
for p in "${rc_all[@]}"; do
    case "${p}" in
        grub-pc|grub-pc-bin|grub-gfxpayload-lists) info "rc conservé (boot) : ${p}" ;;
        *) rc_pkgs+=("${p}") ;;
    esac
done
if [[ ${#rc_pkgs[@]} -gt 0 ]]; then
    info "Purge : ${rc_pkgs[*]}"
    run_silent_apt purge -y "${rc_pkgs[@]}"
    success "Paquets rc purgés (${#rc_pkgs[@]})"
else
    success "Aucun paquet rc à purger"
fi

info "CUPS / bluetooth / avahi / compilers : laissés intacts (desktop)."
success "Purge workstation terminée"
