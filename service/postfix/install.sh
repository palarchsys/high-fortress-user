#!/usr/bin/env bash
# =============================================================================
# File       : service/postfix/install.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Installation de Postfix"
hf_log_info "Installation de Postfix (envoi seul, Internet Site)"
debconf_tmp="$(mktemp)"
sed "s|__HOSTNAME__|$(hostname -f)|g" "$(hf_locate_config_file postfix/debconf.conf)" | grep -v '^#' > "${debconf_tmp}"
hf_run_silent debconf-set-selections "${debconf_tmp}"
rm -f "${debconf_tmp}"
hf_run_silent_apt install --no-install-recommends -y postfix mailutils
hf_run_silent systemctl enable postfix
hf_log_success "Postfix installé"
