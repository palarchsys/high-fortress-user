#!/usr/bin/env bash
# =============================================================================
# File       : service/ufw/configure.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root
detect_ssh_port

title "Configuration UFW (desktop-safe)"
backup_file_once /etc/default/ufw
backup_file_once /etc/ufw/before.rules

info "Politique : deny incoming, ALLOW outgoing, routed ACCEPT"
run_silent ufw default deny incoming
run_silent ufw default allow outgoing

if grep -q '^DEFAULT_FORWARD_POLICY=' /etc/default/ufw; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
else
    echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' >> /etc/default/ufw
fi
run_silent ufw default allow routed

if grep -q '^IPT_MODULES=' /etc/default/ufw; then
    if ! awk -F= '/^IPT_MODULES=/{print}' /etc/default/ufw | grep -q bridge; then
        ipt_val="$(awk -F= '/^IPT_MODULES=/{print substr($0, index($0,"=")+1)}' /etc/default/ufw)"
        ipt_val="${ipt_val#\"}"
        ipt_val="${ipt_val%\"}"
        ipt_val="${ipt_val#\'}"
        ipt_val="${ipt_val%\'}"
        sed -i "s|^IPT_MODULES=.*|IPT_MODULES=\"${ipt_val} bridge\"|" /etc/default/ufw
    fi
else
    echo 'IPT_MODULES="bridge"' >> /etc/default/ufw
fi
if [[ -f /etc/ufw/sysctl.conf ]] && ! grep -q 'bridge-nf-call-iptables' /etc/ufw/sysctl.conf; then
    cat >> /etc/ufw/sysctl.conf << 'EOF'

net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
EOF
fi

if grep -q '^IPV6=' /etc/default/ufw; then
    sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
else
    echo "IPV6=yes" >> /etc/default/ufw
fi

run_silent ufw logging medium

info "SSH limit sur le port détecté ${SSH_PORT}/tcp"

run_silent ufw limit "${SSH_PORT}/tcp" comment 'SSH (limit)'

run_silent ufw allow in on lo
run_silent ufw allow out on lo

title "Activation UFW"
info "Activation d'UFW"
run_silent ufw --force enable
if ! LANG=C LC_ALL=C ufw status | grep -qw "Status: active"; then
    error "UFW n'est pas actif après enable : $(LANG=C LC_ALL=C ufw status)"
fi
success "UFW activé (outgoing ALLOW — Steam/Discord/apt/Brave OK)"
