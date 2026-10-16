#!/usr/bin/env bash
# =============================================================================
# File       : service/crowdsec/configure.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Collections CrowdSec"
hf_log_info "Installation des collections CrowdSec"
hf_run_silent cscli hub update

mapfile -t collections < <(grep -vE '^[[:space:]]*(#|$)' "$(hf_locate_config_file crowdsec/collections.list)")
hf_run_silent cscli collections install --force "${collections[@]}"
hf_log_success "Collections linux, sshd, postfix et liste blanche installées"

hf_log_title "Durée de blocage"
hf_log_info "Configuration de la durée de blocage"
grep -v '^#' "$(hf_locate_config_file crowdsec/profiles.yaml)" > /etc/crowdsec/profiles.yaml
hf_log_success "Blocage de 24 h posé"

hf_log_title "Journaux lus par CrowdSec"
hf_log_info "Configuration des journaux lus par CrowdSec"
{
    grep -v '^#' "$(hf_locate_config_file crowdsec/acquisition.journal.yaml)"
    if [[ -f /var/log/auth.log ]]; then
        grep -v '^#' "$(hf_locate_config_file crowdsec/acquisition.auth.yaml)"
    fi
    if [[ -f /var/log/syslog ]]; then
        grep -v '^#' "$(hf_locate_config_file crowdsec/acquisition.syslog.yaml)"
    fi
    if [[ -f /var/log/mail.log ]]; then
        grep -v '^#' "$(hf_locate_config_file crowdsec/acquisition.mail.yaml)"
    fi
} > /etc/crowdsec/acquisitions.yaml
chmod 644 /etc/crowdsec/acquisitions.yaml
hf_log_success "Journaux SSH, système et courrier configurés"

hf_log_title "Bouncer pare-feu"
hf_log_info "Liaison du bouncer nftables à l'API locale"
cscli bouncers delete firewall-bouncer >/dev/null 2>&1 || true
raw="$(cscli bouncers add firewall-bouncer 2>&1)"
key="$(printf '%s\n' "${raw}" | grep -oE '[A-Za-z0-9/=+]{40,}' | tail -n1)"
if [[ -z "${key}" ]]; then
    hf_log_error "Clé du bouncer CrowdSec introuvable."
fi
bouncer_cfg="/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"
if [[ ! -f "${bouncer_cfg}" ]]; then
    hf_log_error "Fichier bouncer absent : ${bouncer_cfg}"
fi
sed -i "s|^[[:space:]]*api_key:.*|api_key: ${key}|" "${bouncer_cfg}"
hf_log_success "Bouncer nftables relié à l'API locale"

hf_log_info "Activation de CrowdSec et du bouncer"
grep -v '^#' "$(hf_locate_config_file crowdsec/audit.rule)" \
    > /etc/audit/rules.d/hfu-crowdsec.rules
chmod 640 /etc/audit/rules.d/hfu-crowdsec.rules
hf_run_silent augenrules --load

hf_run_silent systemctl enable --now crowdsec
hf_run_silent systemctl enable --now crowdsec-firewall-bouncer
hf_run_silent systemctl restart crowdsec
hf_run_silent systemctl restart crowdsec-firewall-bouncer
hf_log_success "CrowdSec et le bouncer activés"
