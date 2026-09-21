#!/usr/bin/env bash
# =============================================================================
# service/ufw/configure.sh
# =============================================================================
# Politique workstation :
#   incoming deny, outgoing ALLOW, routed ACCEPT si libvirt
# Ne pas ufw --force reset : ça casse les chaînes libvirt/docker.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_ssh_port

title "Configuration UFW (desktop-safe)"
backup_file_once /etc/default/ufw
backup_file_once /etc/ufw/before.rules

info "Politique : deny incoming, ALLOW outgoing..."
run_silent ufw default deny incoming
run_silent ufw default allow outgoing

if virt_present; then
    info "libvirt/KVM : DEFAULT_FORWARD_POLICY=ACCEPT (NAT virbr)..."
    if grep -q '^DEFAULT_FORWARD_POLICY=' /etc/default/ufw; then
        sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    else
        echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' >> /etc/default/ufw
    fi
    run_silent ufw default allow routed
else
    run_silent ufw default deny routed
fi

# IPv6 ON (Steam / Discord / Ubuntu 26.04)
if grep -q '^IPV6=' /etc/default/ufw; then
    sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
else
    echo "IPV6=yes" >> /etc/default/ufw
fi

run_silent ufw logging medium

info "SSH limit sur le port détecté ${SSH_PORT}/tcp..."
# Ne pas bloquer 22 si c'est le port réel.
run_silent ufw limit "${SSH_PORT}/tcp" comment 'SSH (limit)'

run_silent ufw allow in on lo
run_silent ufw allow out on lo

# KDE Connect / avahi / cups : on n'ouvre pas le WAN ; LAN facultatif non touché.

if virt_present; then
    info "Interfaces libvirt (virbr*, virbr*-nic)..."
    for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^virbr|^vnet'); do
        try_silent ufw allow in on "${iface}"
        try_silent ufw allow out on "${iface}"
    done
    # Même si virbr0 n'existe pas encore
    try_silent ufw allow in on virbr0
    try_silent ufw allow out on virbr0
    try_silent systemctl restart libvirtd.service
    try_silent systemctl restart virtnetworkd.service
    success "Règles libvirt posées"
fi

title "Activation UFW"
run_silent ufw --force enable
if ! LANG=C LC_ALL=C ufw status | grep -qw "Status: active"; then
    error "UFW n'est pas actif après enable : $(LANG=C LC_ALL=C ufw status)"
fi
success "UFW actif (outgoing ALLOW — Steam/Discord/Telegram/apt/Firefox OK)"
