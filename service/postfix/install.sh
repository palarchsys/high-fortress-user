#!/usr/bin/env bash
# =============================================================================
# File       : service/postfix/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Installation de Postfix"
g_log_info "Installation de Postfix (envoi seul, Internet Site)"
debconf_tmp="$(mktemp)"
sed "s|__HOSTNAME__|$(hostname -f)|g" "$(g_locate_config_file postfix/debconf.conf)" | grep -v '^#' > "${debconf_tmp}"
g_run_silent debconf-set-selections "${debconf_tmp}"
rm -f "${debconf_tmp}"
g_run_silent_apt install --no-install-recommends -y postfix mailutils
g_run_silent systemctl enable postfix
g_log_success "Postfix installé"
