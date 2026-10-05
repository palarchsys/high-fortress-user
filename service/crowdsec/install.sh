#!/usr/bin/env bash
# =============================================================================
# File       : service/crowdsec/install.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Dépôt CrowdSec"
info "Enregistrement du dépôt CrowdSec"
install -d -m 755 /etc/apt/keyrings
CROWDSEC_KEY="/etc/apt/keyrings/crowdsec_crowdsec-archive-keyring.gpg"
CROWDSEC_LIST="/etc/apt/sources.list.d/crowdsec_crowdsec.list"
curl -fsSL https://packagecloud.io/crowdsec/crowdsec/gpgkey | gpg --dearmor -o "${CROWDSEC_KEY}"
chmod 644 "${CROWDSEC_KEY}"
tee "${CROWDSEC_LIST}" > /dev/null << EOF
deb [signed-by=${CROWDSEC_KEY}] https://packagecloud.io/crowdsec/crowdsec/any any main
EOF
chmod 644 "${CROWDSEC_LIST}"

tee /etc/apt/preferences.d/crowdsec > /dev/null << 'EOF'
Package: crowdsec*
Pin: origin packagecloud.io
Pin-Priority: 700
EOF
chmod 644 /etc/apt/preferences.d/crowdsec
run_silent_apt update
success "Dépôt CrowdSec enregistré"

title "Installation de CrowdSec"
info "Installation de CrowdSec"
run_silent_apt install -y crowdsec crowdsec-firewall-bouncer-nftables
cs_ver="$(dpkg-query -W -f '${Version}' crowdsec 2>/dev/null || true)"
if [[ "${cs_ver}" == 1.4.* ]]; then
    error "CrowdSec ${cs_ver} vient du dépôt Ubuntu, pas de packagecloud."
fi
run_silent systemctl daemon-reload
success "CrowdSec installé (${cs_ver})"
