#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/desktop/install.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   service/desktop/install.sh — logiciels du poste
# =============================================================================

# Installés après le durcissement, depuis leur dépôt officiel :
#   Brave       dépôt apt publié sur https://brave.com/linux/
#   Discord     paquet .deb le plus récent de https://discord.com/download
#   Vencord     installeur officiel, qui modifie le Discord .deb
#   Thunderbird dépôt apt Mozilla, suite thunderbird-deb
#   KeePassXC   paquet Ubuntu (dépôt de la distribution)
#
# Snap est déjà retiré. Vencord ne prend pas en charge un Discord
# empaqueté autrement que par le .deb officiel.
#
# Arguments reçus de run.sh : $1 répertoire des sources, $2 profil.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_current_user

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

title "Dépôt Thunderbird (Mozilla)"
# Le paquet Ubuntu thunderbird installe le snap. Le dépôt Mozilla publie
# le vrai programme. Sa priorité passe devant l'enveloppe Snap, et la
# version 2:1snap* est refusée. Documentation :
# https://support.mozilla.org/kb/installing-thunderbird-linux
install -d -m 0755 /etc/apt/keyrings /etc/apt/preferences.d
curl -fsSL -o /etc/apt/keyrings/packages.mozilla.org.asc \
    https://packages.mozilla.org/apt/repo-signing-key.gpg
# Le format affiché par gpg change selon la version (espaces ou non).
# Le champ fpr du mode colonnes est stable.
mozilla_fpr="$(gpg --show-keys --with-colons /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')"
if [[ "${mozilla_fpr}" != "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3" ]]; then
    error "Empreinte de la clé Mozilla inattendue (${mozilla_fpr:-vide})."
fi
chmod 644 /etc/apt/keyrings/packages.mozilla.org.asc
cat > /etc/apt/sources.list.d/mozilla.sources << 'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: thunderbird-deb
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
cat > /etc/apt/preferences.d/mozilla-thunderbird << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: thunderbird
Pin: version 2:1snap*
Pin-Priority: -1
EOF
chmod 644 /etc/apt/sources.list.d/mozilla.sources \
    /etc/apt/preferences.d/mozilla-thunderbird
success "Dépôt Thunderbird Mozilla enregistré"

title "Brave, Thunderbird, KeePassXC"
run_silent_apt update
if ! apt-cache show keepassxc >/dev/null 2>&1; then
    info "KeePassXC est dans le composant universe d'Ubuntu."
    run_silent_apt install -y software-properties-common
    run_silent add-apt-repository -y universe
    run_silent_apt update
fi
run_silent_apt install -y --allow-downgrades brave-browser thunderbird keepassxc
tb_ver="$(dpkg-query -W -f '${Version}' thunderbird 2>/dev/null || true)"
if [[ "${tb_ver}" == *snap* || -z "${tb_ver}" ]]; then
    error "Thunderbird installé n'est pas le paquet Mozilla (version ${tb_ver:-vide})."
fi
success "Brave, Thunderbird et KeePassXC installés"

title "Discord"
if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    error "Le paquet Discord officiel est publié pour amd64. Architecture détectée : $(dpkg --print-architecture)."
fi
discord_deb="$(mktemp --suffix=.deb)"
# -s masque la barre de progression. -f fait échouer curl si le serveur refuse.
curl -fsSL --retry 3 -o "${discord_deb}" \
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
discord_boot_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/discord-bootstrap.log"
mkdir -p "$(dirname "${discord_boot_log}")"
# Le téléchargeur écrit « Install Complete » et le nom du dossier.
# On le garde dans le journal pour ne pas couper la lecture du terminal.
if ! sudo -u "${CURRENT_USER}" -H \
    /usr/share/discord/updater_bootstrap --no-zenity \
    "${CURRENT_HOME}/.config/discord" stable "https://updates.discord.com/" \
    >"${discord_boot_log}" 2>&1; then
    error "Le téléchargeur Discord n'a pas déposé le client. Détail : ${discord_boot_log}"
fi
discord_app="$(find "${CURRENT_HOME}/.config/discord" -mindepth 1 -maxdepth 1 -type d -name 'app-*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
if [[ -z "${discord_app}" || ! -d "${discord_app}/resources" ]]; then
    error "Client Discord introuvable sous ${CURRENT_HOME}/.config/discord/app-*/resources."
fi
info "Client Discord : ${discord_app}"
vencord_cli="$(mktemp)"
curl -fsSL --retry 3 -o "${vencord_cli}" \
    "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux"
chmod 755 "${vencord_cli}"
# --location vise le dossier app-* . --branch est incompatible avec --location.
# La sortie de l'installeur (INFO, Success) va dans le journal.
export SUDO_USER="${CURRENT_USER}"
vencord_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/vencord-install.log"
if ! "${vencord_cli}" --install --location "${discord_app}" >"${vencord_log}" 2>&1; then
    rm -f "${vencord_cli}"
    error "L'installation de Vencord a échoué. Détail : ${vencord_log} — https://vencord.dev/support"
fi
rm -f "${vencord_cli}"
success "Vencord installé sur ${discord_app}"

# Brave, Thunderbird ou Discord ont pu mettre à jour l'unité ClamAV
# après son démarrage. Le rechargement évite l'avertissement systemctl.
systemctl daemon-reload >/dev/null 2>&1 || true
success "Logiciels du poste installés"
