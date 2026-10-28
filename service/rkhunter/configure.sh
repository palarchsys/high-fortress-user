#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root
g_get_current_user
W_ACCOUNT_USER="${CURRENT_USER}"
export W_ACCOUNT_USER

g_log_title "Configuration rkhunter"
g_log_info "Configuration de rkhunter"
envsubst '$W_ACCOUNT_USER' < "$(g_locate_config_file rkhunter/rkhunter.conf.local)" > /etc/rkhunter.conf.local
chmod 644 /etc/rkhunter.conf.local
g_log_success "rkhunter.conf.local posé"

if grep -qE '^[[:space:]]*WEB_CMD=' /etc/rkhunter.conf; then
    sed -i 's|^[[:space:]]*WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf
fi

g_log_info "Base rkhunter (--propupd) après la purge des paquets."
install -d -m 755 "${G_CONFIG_BASE_DIRECTORY}/bin"
install -m 755 \
    "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/refresh-db.sh" \
    "${G_CONFIG_BASE_DIRECTORY}/bin/rkhunter-refresh-db.sh"
