#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/crowdsec/install.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Ajoute le dépôt apt officiel packagecloud et installe CrowdSec
#   avec le bouncer qui bloque les adresses dans le pare-feu nftables.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Dépôt CrowdSec"
install -d -m 755 /etc/apt/keyrings
CROWDSEC_KEY="/etc/apt/keyrings/crowdsec_crowdsec-archive-keyring.gpg"
CROWDSEC_LIST="/etc/apt/sources.list.d/crowdsec_crowdsec.list"
curl -fsSL https://packagecloud.io/crowdsec/crowdsec/gpgkey | gpg --dearmor -o "${CROWDSEC_KEY}"
chmod 644 "${CROWDSEC_KEY}"
tee "${CROWDSEC_LIST}" > /dev/null << EOF
deb [signed-by=${CROWDSEC_KEY}] https://packagecloud.io/crowdsec/crowdsec/any any main
EOF
chmod 644 "${CROWDSEC_LIST}"
# Le dépôt Ubuntu peut proposer une version trop ancienne pour le hub.
tee /etc/apt/preferences.d/crowdsec > /dev/null << 'EOF'
Package: crowdsec*
Pin: origin packagecloud.io
Pin-Priority: 700
EOF
chmod 644 /etc/apt/preferences.d/crowdsec
run_silent_apt update
success "Dépôt CrowdSec enregistré"

title "Installation de CrowdSec"
run_silent_apt install -y crowdsec crowdsec-firewall-bouncer-nftables
cs_ver="$(dpkg-query -W -f '${Version}' crowdsec 2>/dev/null || true)"
if [[ "${cs_ver}" == 1.4.* ]]; then
    error "CrowdSec ${cs_ver} vient du dépôt Ubuntu, pas de packagecloud."
fi
run_silent systemctl daemon-reload
success "CrowdSec installé (${cs_ver})"
