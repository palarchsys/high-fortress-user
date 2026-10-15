#!/usr/bin/env bash
# =============================================================================
# File       : service/apparmor/userns.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Profils AppArmor userns"

hfu_check_userns_profile() {
    local token="$1"
    local self="$2"
    grep -R --exclude="${self}" --exclude-dir=disable --exclude-dir=local \
        -F -q -- "${token}" /etc/apparmor.d 2>/dev/null
}

hfu_install_userns_profile() {
    local file="$1"
    local token="$2"
    local dest="/etc/apparmor.d/${file}"
    if hfu_check_userns_profile "${token}" "${file}"; then
        rm -f "${dest}"
        hf_log_info "${token} déjà couvert — pas de second profil"
        cat >/dev/null
        return 0
    fi
    hf_log_info "Chargement du profil userns ${file}"
    cat > "${dest}"
    chmod 644 "${dest}"
    if apparmor_parser -r "${dest}"; then
        hf_log_success "Profil userns chargé : ${file}"
    else
        hf_log_warn "Profil ${file} refusé par le parseur — retiré"
        rm -f "${dest}"
    fi
}

hfu_write_userns_file() {
    local file="$1"
    local token="$2"
    local rel="$3"
    grep -v '^#' "$(hf_locate_config_file "apparmor/${rel}")" | hfu_install_userns_profile "${file}" "${token}"
}

hfu_write_userns_file hfu-brave "/opt/brave.com/brave/brave" hfu-brave
hfu_write_userns_file hfu-discord "/usr/share/discord/Discord" hfu-discord

if [[ -f /etc/apparmor.d/hfu-telegram ]]; then
    hf_run_optional apparmor_parser -R /etc/apparmor.d/hfu-telegram
fi
if [[ -f /etc/apparmor.d/hfu-telegram-home ]]; then
    hf_run_optional apparmor_parser -R /etc/apparmor.d/hfu-telegram-home
fi
rm -f /etc/apparmor.d/hfu-telegram /etc/apparmor.d/hfu-telegram-home

if hfu_check_userns_profile "bin_steam.sh" "hfu-steam" \
    || hfu_check_userns_profile "/usr/games/steam" "hfu-steam" \
    || hfu_check_userns_profile "/usr/bin/steam" "hfu-steam"; then
    rm -f /etc/apparmor.d/hfu-steam
    hf_log_info "Steam déjà couvert par un profil existant"
else
    hfu_write_userns_file hfu-steam "/usr/bin/steam-not-covered" hfu-steam
fi

hfu_write_userns_file hfu-thunderbird "/usr/lib/thunderbird/thunderbird" hfu-thunderbird

hf_log_info "Rechargement d'AppArmor"
hf_run_optional systemctl reload apparmor
hf_log_success "Profils userns chargés, restriction Ubuntu conservée"
