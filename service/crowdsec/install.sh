#!/usr/bin/env bash
# =============================================================================
# File       : service/crowdsec/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Dépôt CrowdSec"
g_log_info "Enregistrement du dépôt CrowdSec"
install -d -m 755 /etc/apt/keyrings
CROWDSEC_KEY="/etc/apt/keyrings/crowdsec_crowdsec-archive-keyring.gpg"
CROWDSEC_LIST="/etc/apt/sources.list.d/crowdsec_crowdsec.list"
curl -fsSL https://packagecloud.io/crowdsec/crowdsec/gpgkey | gpg --dearmor -o "${CROWDSEC_KEY}"
chmod 644 "${CROWDSEC_KEY}"
sed "s|__KEY__|${CROWDSEC_KEY}|g" "$(g_locate_config_file crowdsec/package.list)" \
    | grep -v '^#' > "${CROWDSEC_LIST}"
chmod 644 "${CROWDSEC_LIST}"

grep -v '^#' "$(g_locate_config_file crowdsec/preferences.conf)" > /etc/apt/preferences.d/crowdsec
chmod 644 /etc/apt/preferences.d/crowdsec
g_run_silent_apt update
g_log_success "Dépôt CrowdSec enregistré"

g_log_title "Installation de CrowdSec"
g_log_info "Installation de CrowdSec"
g_run_silent_apt install -y crowdsec crowdsec-firewall-bouncer-nftables
cs_ver="$(dpkg-query -W -f '${Version}' crowdsec 2>/dev/null || true)"
if [[ "${cs_ver}" == 1.4.* ]]; then
    g_log_error "CrowdSec ${cs_ver} vient du dépôt Ubuntu, pas de packagecloud."
fi
g_run_silent systemctl daemon-reload
g_log_success "CrowdSec installé (${cs_ver})"
