#!/usr/bin/env bash
# =============================================================================
# File       : service/crowdsec/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Collections CrowdSec"
g_log_info "Installation des collections CrowdSec"
g_run_silent cscli hub update

mapfile -t collections < <(grep -vE '^[[:space:]]*(#|$)' "$(g_locate_config_file crowdsec/collections.list)")
g_run_silent cscli collections install --force "${collections[@]}"
g_log_success "Collections linux, sshd, postfix et liste blanche installées"

g_log_info "Recherche des collections optionnelles"
while read -r name; do
    [[ -n "${name}" && "${name}" != \#* ]] || continue
    if cscli collections install --force "${name}" >/dev/null 2>&1; then
        g_log_info "Collection ${name} présente"
    else
        g_log_warn "Collection ${name} absente du hub"
    fi
done < "$(g_locate_config_file crowdsec/optional.list)"
g_log_success "Collections optionnelles traitées"

g_log_title "Durée de blocage"
g_log_info "Configuration de la durée de blocage"
# shellcheck disable=SC1091
source "$(g_locate_config_file crowdsec/ban.conf)"
if [[ ! "${W_CROWDSEC_BAN_DURATION}" =~ ^[0-9]+[smhd]$ ]]; then
    g_log_error "durée de blocage invalide"
fi
grep -v '^#' "$(g_locate_config_file crowdsec/profiles.yaml)" \
    | sed "s/duration: .*/duration: ${W_CROWDSEC_BAN_DURATION}/" \
    > /etc/crowdsec/profiles.yaml
g_log_success "Blocage posé (${W_CROWDSEC_BAN_DURATION})"

g_log_title "Journaux lus par CrowdSec"
g_log_info "Configuration des journaux lus par CrowdSec"
{
    grep -v '^#' "$(g_locate_config_file crowdsec/acquisition-journal.yaml)"
    if [[ -f /var/log/auth.log ]]; then
        grep -v '^#' "$(g_locate_config_file crowdsec/acquisition-auth.yaml)"
    fi
    if [[ -f /var/log/syslog ]]; then
        grep -v '^#' "$(g_locate_config_file crowdsec/acquisition-syslog.yaml)"
    fi
    if [[ -f /var/log/mail.log ]]; then
        grep -v '^#' "$(g_locate_config_file crowdsec/acquisition-mail.yaml)"
    fi
} > /etc/crowdsec/acquisitions.yaml
chmod 644 /etc/crowdsec/acquisitions.yaml
g_log_success "Journaux SSH, système et courrier configurés"

g_log_title "Bouncer pare-feu"
g_log_info "Liaison du bouncer nftables à l'API locale"
cscli bouncers delete firewall-bouncer >/dev/null 2>&1 || true
raw="$(cscli bouncers add firewall-bouncer 2>&1)"
key="$(printf '%s\n' "${raw}" | grep -oE '[A-Za-z0-9/=+]{40,}' | tail -n1)"
if [[ -z "${key}" ]]; then
    g_log_error "Clé du bouncer CrowdSec introuvable."
fi
bouncer_cfg="/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"
if [[ ! -f "${bouncer_cfg}" ]]; then
    g_log_error "Fichier bouncer absent : ${bouncer_cfg}"
fi
sed -i "s|^[[:space:]]*api_key:.*|api_key: ${key}|" "${bouncer_cfg}"
g_log_success "Bouncer nftables relié à l'API locale"

g_log_info "Activation de CrowdSec et du bouncer"
grep -v '^#' "$(g_locate_config_file crowdsec/audit.rules)" \
    > /etc/audit/rules.d/w-crowdsec.rules
chmod 640 /etc/audit/rules.d/w-crowdsec.rules
g_run_silent augenrules --load

g_run_silent systemctl enable --now crowdsec
g_run_silent systemctl enable --now crowdsec-firewall-bouncer
g_run_silent systemctl restart crowdsec
g_run_silent systemctl restart crowdsec-firewall-bouncer
g_log_success "CrowdSec et le bouncer activés"
