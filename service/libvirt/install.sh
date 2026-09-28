#!/usr/bin/env bash
# =============================================================================
# service/libvirt/install.sh
# =============================================================================
# Installe QEMU (paquet Ubuntu qemu-system-x86) et le démon libvirt.
# Sur Ubuntu 26.04, libvirt 12 livre un seul démon : libvirtd.service.
# Le pilote réseau (NAT virbr0) est chargé par ce démon. L'unité séparée
# virtnetworkd.service n'est pas dans les paquets de cette version ; elle
# est activée seulement si le paquet la fournit.
#
# Le paquet ajoute le groupe libvirt aux comptes du groupe sudo.
# Le mot de passe, le nom et le dossier personnel ne changent pas.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "KVM et libvirt"
# qemu-kvm est un paquet virtuel. Ubuntu en propose deux réalisations
# (qemu-system-x86 et qemu-system-x86-hwe) et apt refuse de choisir.
# qemu-system-x86 est le paquet du dépôt Ubuntu de la version installée.
run_silent_apt install -y qemu-system-x86 libvirt-daemon-system
run_silent systemctl enable --now libvirtd.service
if ! systemctl is-active --quiet libvirtd.service; then
    error "libvirtd.service n'est pas actif."
fi
success "libvirtd.service actif"

if systemctl cat virtnetworkd.service >/dev/null 2>&1; then
    run_silent systemctl enable --now virtnetworkd.service
    success "virtnetworkd.service actif"
else
    info "virtnetworkd.service absent : le réseau virtuel est géré par libvirtd."
fi

if command -v virsh >/dev/null 2>&1; then
    if virsh net-info default >/dev/null 2>&1; then
        virsh net-autostart default >/dev/null 2>&1 || true
        virsh net-start default >/dev/null 2>&1 || true
        success "Réseau NAT default demandé au démarrage"
    else
        info "Réseau default pas encore défini."
    fi
fi
