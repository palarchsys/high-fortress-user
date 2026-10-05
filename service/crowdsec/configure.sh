#!/usr/bin/env bash
# =============================================================================
# File       : service/crowdsec/configure.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Collections CrowdSec"
info "Installation des collections CrowdSec"
run_silent cscli hub update

run_silent cscli collections install --force \
    crowdsecurity/linux \
    crowdsecurity/sshd \
    crowdsecurity/postfix \
    crowdsecurity/iptables \
    crowdsecurity/whitelist-good-actors
success "Collections linux, sshd, postfix et liste blanche installées"

title "Durée de blocage"
info "Configuration de la durée de blocage"
tee /etc/crowdsec/profiles.yaml > /dev/null << 'EOF'
name: default_ip_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
  - type: ban
    duration: 24h
on_success: break
---
name: default_range_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Range"
decisions:
  - type: ban
    duration: 24h
on_success: break
EOF
success "Blocage de 24 h posé"

title "Journaux lus par CrowdSec"
info "Configuration des journaux lus par CrowdSec"
{
    echo "source: journalctl"
    echo "journalctl_filter:"
    echo "  - _SYSTEMD_UNIT=ssh.service"
    echo "labels:"
    echo "  type: syslog"
    if [[ -f /var/log/auth.log ]]; then
        cat << 'EOF'
---
source: file
file: /var/log/auth.log
labels:
  type: syslog
EOF
    fi
    if [[ -f /var/log/syslog ]]; then
        cat << 'EOF'
---
source: file
file: /var/log/syslog
labels:
  type: syslog
EOF
    fi
    if [[ -f /var/log/mail.log ]]; then
        cat << 'EOF'
---
source: file
file: /var/log/mail.log
labels:
  type: syslog
EOF
    fi
} > /etc/crowdsec/acquisitions.yaml
chmod 644 /etc/crowdsec/acquisitions.yaml
success "Journaux SSH, système et courrier configurés"

title "Bouncer pare-feu"
info "Liaison du bouncer nftables à l'API locale"
cscli bouncers delete firewall-bouncer >/dev/null 2>&1 || true
raw="$(cscli bouncers add firewall-bouncer 2>&1)"
key="$(printf '%s\n' "${raw}" | grep -oE '[A-Za-z0-9/=+]{40,}' | tail -n1)"
if [[ -z "${key}" ]]; then
    error "Clé du bouncer CrowdSec introuvable."
fi
bouncer_cfg="/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"
if [[ ! -f "${bouncer_cfg}" ]]; then
    error "Fichier bouncer absent : ${bouncer_cfg}"
fi
sed -i "s|^[[:space:]]*api_key:.*|api_key: ${key}|" "${bouncer_cfg}"
success "Bouncer nftables relié à l'API locale"

info "Activation de CrowdSec et du bouncer"
printf '%s\n' '-a always,exit -F arch=b64 -F dir=/etc/crowdsec -F perm=wa -F key=crowdsec-config' \
    > /etc/audit/rules.d/hfu-crowdsec.rules
chmod 640 /etc/audit/rules.d/hfu-crowdsec.rules
run_silent augenrules --load

run_silent systemctl enable --now crowdsec
run_silent systemctl enable --now crowdsec-firewall-bouncer
run_silent systemctl restart crowdsec
run_silent systemctl restart crowdsec-firewall-bouncer
success "CrowdSec et le bouncer activés"
