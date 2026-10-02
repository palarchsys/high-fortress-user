#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/ufw/configure.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/ufw/configure.sh
# =============================================================================

# Politique workstation :
#   incoming deny, outgoing ALLOW, routed ACCEPT
# Ne pas ufw --force reset : ça casse les chaînes docker.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_ssh_port

title "Configuration UFW (desktop-safe)"
backup_file_once /etc/default/ufw
backup_file_once /etc/ufw/before.rules

info "Politique : deny incoming, ALLOW outgoing, routed ACCEPT..."
run_silent ufw default deny incoming
run_silent ufw default allow outgoing

# Ubuntu 26.04 ufw-framework : le défaut DROP sur FORWARD bloque un pont
# déjà présent. La politique est posée tout de suite : un rechargement
# ultérieur ne la remet pas à DROP.
if grep -q '^DEFAULT_FORWARD_POLICY=' /etc/default/ufw; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
else
    echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' >> /etc/default/ufw
fi
run_silent ufw default allow routed

# Charger bridge avant les sysctl UFW, puis désactiver
# netfilter sur le pont (ufw-framework NOTES, manpage resolute).
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

# High-Fortress User — pont (ufw-framework, Ubuntu 26.04)
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
EOF
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

title "Activation UFW"
run_silent ufw --force enable
if ! LANG=C LC_ALL=C ufw status | grep -qw "Status: active"; then
    error "UFW n'est pas actif après enable : $(LANG=C LC_ALL=C ufw status)"
fi
success "UFW actif (outgoing ALLOW — Steam/Discord/apt/Brave OK)"
