#!/usr/bin/env bash
# =============================================================================
# service/unattended-upgrades/configure.sh
# =============================================================================
# Sécurité Ubuntu + ESM seulement — pas -updates (peut changer Mesa / Proton en session).
# Les dépôts Brave, Steam, Discord, Telegram ne sont pas dans ces origines :
# leurs mises à jour restent celles de leur propre dépôt, non réécrit ici.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Configuration unattended-upgrades (security only)"
ensure_dir /etc/apt/apt.conf.d 755

tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

tee /etc/apt/apt.conf.d/51high-fortress-user > /dev/null << 'EOF'
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}";
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
};
# Pas de blacklist : Firefox, Thunderbird, QEMU et libvirt reçoivent
# les correctifs de sécurité Ubuntu. Les clients tiers ne sont pas
# dans ces origines.
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

run_silent systemctl enable --now unattended-upgrades
success "unattended-upgrades : security only, reboot auto OFF"
