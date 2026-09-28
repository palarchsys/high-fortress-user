#!/usr/bin/env bash
# =============================================================================
# service/apparmor/userns.sh
# =============================================================================
# Ubuntu n'autorise un programme à créer un user namespace que s'il possède
# un profil AppArmor qui contient la règle « userns ». Brave, Discord,
# Thunderbird et Steam s'en servent pour leur bac à sable interne.
#
# Le profil ajouté ici est « unconfined » : AppArmor lui donne un nom et
# la règle userns, et laisse l'application appliquer son propre bac à sable.
# C'est le modèle publié par Mozilla pour Firefox.
#
# Si le paquet a déjà déposé un profil pour le même binaire, on n'en ajoute
# pas un second : deux profils sur le même chemin font échouer le parseur.
# Le snap Telegram et le snap Thunderbird ont le profil fourni par snapd.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Profils AppArmor userns"

# token : chemin de binaire déjà couvert par un autre fichier de /etc/apparmor.d.
# self  : nom du fichier que nous écrivons, exclu de la recherche.
profile_covers() {
    local token="$1"
    local self="$2"
    grep -R --exclude="${self}" --exclude-dir=disable --exclude-dir=local \
        -F -q -- "${token}" /etc/apparmor.d 2>/dev/null
}

# Lit le profil sur l'entrée standard et le charge.
# Un refus du parseur retire seulement ce fichier.
install_userns_profile() {
    local file="$1"
    local token="$2"
    local dest="/etc/apparmor.d/${file}"
    if profile_covers "${token}" "${file}"; then
        rm -f "${dest}"
        info "${token} déjà couvert — pas de second profil"
        cat >/dev/null
        return 0
    fi
    cat > "${dest}"
    chmod 644 "${dest}"
    if apparmor_parser -r "${dest}"; then
        success "Profil userns chargé : ${file}"
    else
        warn "Profil ${file} refusé par le parseur — retiré"
        rm -f "${dest}"
    fi
}

install_userns_profile hfu-brave "/opt/brave.com/brave/brave" << 'EOF'
# Brave : binaire du dépôt apt https://brave.com/linux/
abi <abi/4.0>,
include <tunables/global>

profile hfu-brave /opt/brave.com/brave{,-beta,-nightly}/{brave,chrome} flags=(unconfined) {
  userns,

  include if exists <local/hfu-brave>
}
EOF

install_userns_profile hfu-discord "/usr/share/discord/Discord" << 'EOF'
# Discord : binaire du paquet .deb officiel
abi <abi/4.0>,
include <tunables/global>

profile hfu-discord /usr/share/{discord/Discord,discord-canary/DiscordCanary,discord-ptb/DiscordPTB} flags=(unconfined) {
  userns,

  include if exists <local/hfu-discord>
}
EOF

install_userns_profile hfu-telegram "/opt/Telegram/Telegram" << 'EOF'
# Telegram : binaire du tarball officiel (/opt/Telegram ou ~/Telegram).
# Le paquet snap telegram-desktop est couvert par le profil snapd.
abi <abi/4.0>,
include <tunables/global>

profile hfu-telegram /opt/Telegram/Telegram flags=(unconfined) {
  userns,

  include if exists <local/hfu-telegram>
}

profile hfu-telegram-home @{HOME}/Telegram/Telegram flags=(unconfined) {
  userns,

  include if exists <local/hfu-telegram-home>
}
EOF

if profile_covers "bin_steam.sh" "hfu-steam" \
    || profile_covers "/usr/games/steam" "hfu-steam" \
    || profile_covers "/usr/bin/steam" "hfu-steam"; then
    rm -f /etc/apparmor.d/hfu-steam
    info "Steam déjà couvert par un profil existant"
else
    install_userns_profile hfu-steam "/usr/bin/steam-not-covered" << 'EOF'
abi <abi/4.0>,
include <tunables/global>

profile hfu-steam /usr/{bin/steam,games/steam,lib/steam/bin_steam.sh} flags=(unconfined) {
  userns,

  include if exists <local/hfu-steam>
}
EOF
fi

install_userns_profile hfu-thunderbird "/usr/lib/thunderbird/thunderbird" << 'EOF'
# Thunderbird installé hors snap, sous /usr/lib ou /opt.
# Le paquet snap a son profil snap.thunderbird.
abi <abi/4.0>,
include <tunables/global>

profile hfu-thunderbird /usr/lib/thunderbird/thunderbird{,-bin} flags=(unconfined) {
  userns,

  include if exists <local/hfu-thunderbird>
}

profile hfu-thunderbird-opt /opt/thunderbird/thunderbird{,-bin} flags=(unconfined) {
  userns,

  include if exists <local/hfu-thunderbird-opt>
}
EOF

try_silent systemctl reload apparmor
success "Profils userns en place, restriction Ubuntu conservée"
