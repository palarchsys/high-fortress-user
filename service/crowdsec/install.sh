#!/usr/bin/env bash
# =============================================================================
# File       : service/crowdsec/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Dépôt CrowdSec"
hf_log_info "Enregistrement du dépôt CrowdSec"
install -d -m 755 /etc/apt/keyrings
CROWDSEC_KEY="/etc/apt/keyrings/crowdsec_crowdsec-archive-keyring.gpg"
CROWDSEC_LIST="/etc/apt/sources.list.d/crowdsec_crowdsec.list"
curl -fsSL https://packagecloud.io/crowdsec/crowdsec/gpgkey | gpg --dearmor -o "${CROWDSEC_KEY}"
chmod 644 "${CROWDSEC_KEY}"
sed "s|__KEY__|${CROWDSEC_KEY}|g" "$(hf_locate_config_file crowdsec/crowdsec.list)" \
    | grep -v '^#' > "${CROWDSEC_LIST}"
chmod 644 "${CROWDSEC_LIST}"

grep -v '^#' "$(hf_locate_config_file crowdsec/preferences)" > /etc/apt/preferences.d/crowdsec
chmod 644 /etc/apt/preferences.d/crowdsec
hf_run_silent_apt update
hf_log_success "Dépôt CrowdSec enregistré"

hf_log_title "Installation de CrowdSec"
hf_log_info "Installation de CrowdSec"
hf_run_silent_apt install -y crowdsec crowdsec-firewall-bouncer-nftables
cs_ver="$(dpkg-query -W -f '${Version}' crowdsec 2>/dev/null || true)"
if [[ "${cs_ver}" == 1.4.* ]]; then
    hf_log_error "CrowdSec ${cs_ver} vient du dépôt Ubuntu, pas de packagecloud."
fi
hf_run_silent systemctl daemon-reload
hf_log_success "CrowdSec installé (${cs_ver})"
