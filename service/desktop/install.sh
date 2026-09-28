#!/usr/bin/env bash
# =============================================================================
# service/desktop/install.sh — logiciels du poste
# =============================================================================
# Installés après le durcissement, depuis leur dépôt officiel :
#   Brave       dépôt apt publié sur https://brave.com/linux/
#   Telegram    paquet snap telegram-desktop (éditeur Telegram)
#   Discord     paquet .deb le plus récent de https://discord.com/download
#   Vencord     installeur officiel, qui modifie le Discord .deb
#   Thunderbird paquet Ubuntu (dépôt de la distribution)
#   KeePassXC   paquet Ubuntu (dépôt de la distribution)
#   QEMU        paquet Ubuntu qemu-system-x86, installé avec libvirt
#               dans service/libvirt/install.sh
#
# Vencord ne prend pas en charge le Discord snap : le .deb officiel est
# donc le format installé. Le snap Telegram est indépendant de Discord.
#
# Arguments reçus de run.sh : $1 répertoire des sources, $2 profil.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_current_user

title "Retrait de Firefox"
# Le navigateur du poste est Brave. Le paquet Ubuntu « firefox » est un
# paquet de transition qui réinstalle le snap. On retire les deux, puis
# on bloque le paquet pour qu'une mise à jour du bureau ne le ramène pas.
if snap list firefox >/dev/null 2>&1; then
    run_silent snap remove --purge firefox
    success "Snap Firefox retiré"
else
    info "Snap Firefox absent"
fi
if dpkg-query -W -f '${Status}' firefox 2>/dev/null | grep -q 'install ok'; then
    run_silent_apt purge -y firefox
    success "Paquet Firefox retiré"
else
    info "Paquet Firefox absent"
fi
if apt-mark showhold 2>/dev/null | grep -qx firefox; then
    info "Paquet firefox déjà bloqué"
else
    apt-mark hold firefox >/dev/null
    success "Paquet firefox bloqué (le bureau ne le réinstalle pas)"
fi

title "Dépôt apt Brave"
# Fichiers ajoutés à côté des sources Ubuntu. Les fichiers déjà présents
# (Ubuntu, Steam, etc.) ne sont pas réécrits.
install -d -m 755 /usr/share/keyrings /etc/apt/sources.list.d
curl -fsSL -o /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
curl -fsSL -o /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
chmod 644 /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    /etc/apt/sources.list.d/brave-browser-release.sources
success "Dépôt Brave enregistré"

title "Brave, Thunderbird, KeePassXC"
run_silent_apt update
if ! apt-cache show keepassxc >/dev/null 2>&1; then
    info "KeePassXC est dans le composant universe d'Ubuntu."
    run_silent_apt install -y software-properties-common
    run_silent add-apt-repository -y universe
    run_silent_apt update
fi
run_silent_apt install -y brave-browser thunderbird keepassxc
success "Brave, Thunderbird et KeePassXC installés"

title "Telegram"
# snapd est le client du dépôt Snap. Le paquet telegram-desktop y est
# publié par Telegram et se met à jour par ce canal.
run_silent_apt install -y snapd
run_silent snap install telegram-desktop
success "Telegram installé"

title "Discord"
if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    error "Le paquet Discord officiel est publié pour amd64. Architecture détectée : $(dpkg --print-architecture)."
fi
discord_deb="$(mktemp --suffix=.deb)"
curl -fL --retry 3 -o "${discord_deb}" \
    "https://discord.com/api/download?platform=linux&format=deb"
deb_pkg="$(dpkg-deb -f "${discord_deb}" Package 2>/dev/null || true)"
deb_arch="$(dpkg-deb -f "${discord_deb}" Architecture 2>/dev/null || true)"
if [[ "${deb_pkg}" != "discord" || "${deb_arch}" != "amd64" ]]; then
    rm -f "${discord_deb}"
    error "Le fichier téléchargé n'est pas le paquet Discord amd64 (paquet=${deb_pkg:-?} arch=${deb_arch:-?})."
fi
run_silent_apt install -y "${discord_deb}"
rm -f "${discord_deb}"
success "Discord installé ($(dpkg-query -W -f '${Version}' discord 2>/dev/null || echo version inconnue))"

title "Vencord"
# Le .deb officiel ne contient pas l'application : /usr/bin/discord
# télécharge le client dans ~/.config/discord/app-<version>/.
# Vencord ne reconnaît que ce dossier (resources/app.asar), pas le
# lanceur de /usr/share/discord. D'où « Discord stable not found »
# tant que le téléchargement n'a pas eu lieu.
info "Téléchargement du client Discord dans ${CURRENT_HOME}/.config/discord ..."
install -d -m 755 -o "${CURRENT_USER}" -g "${CURRENT_USER}" "${CURRENT_HOME}/.config/discord"
if ! sudo -u "${CURRENT_USER}" -H \
    /usr/share/discord/updater_bootstrap --no-zenity \
    "${CURRENT_HOME}/.config/discord" stable "https://updates.discord.com/"; then
    error "Le téléchargeur Discord n'a pas déposé le client dans ${CURRENT_HOME}/.config/discord."
fi
discord_app="$(find "${CURRENT_HOME}/.config/discord" -mindepth 1 -maxdepth 1 -type d -name 'app-*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
if [[ -z "${discord_app}" || ! -d "${discord_app}/resources" ]]; then
    error "Client Discord introuvable sous ${CURRENT_HOME}/.config/discord/app-*/resources."
fi
info "Client Discord : ${discord_app}"
vencord_cli="$(mktemp)"
curl -fL --retry 3 -o "${vencord_cli}" \
    "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux"
chmod 755 "${vencord_cli}"
# --location vise le dossier app-* . --branch est incompatible avec --location.
export SUDO_USER="${CURRENT_USER}"
if ! "${vencord_cli}" --install --location "${discord_app}"; then
    rm -f "${vencord_cli}"
    error "L'installation de Vencord a échoué. Aide : https://vencord.dev/support"
fi
rm -f "${vencord_cli}"
success "Vencord installé sur ${discord_app}"

success "Logiciels du poste installés"
