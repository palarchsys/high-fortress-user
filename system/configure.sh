#!/usr/bin/env bash
# =============================================================================
# system/configure.sh
# =============================================================================
# Rôle       : PAM, sysctl, journald, modules et bandeaux.
#              Les comptes humains (mot de passe, groupes, home, shell)
#              ne sont pas modifiés. hostname, hosts, swap, USB,
#              compilateurs et /tmp non plus.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"

require_root
detect_current_user

title "Algorithme des mots de passe (Lynis AUTH-9229)"
info "ENCRYPT_METHOD YESCRYPT (aucun chpasswd / chage)..."
if grep -q "^ENCRYPT_METHOD" /etc/login.defs; then
    sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD YESCRYPT/' /etc/login.defs
else
    echo "ENCRYPT_METHOD YESCRYPT" >> /etc/login.defs
fi
success "YESCRYPT pour les *nouveaux* hash — mots de passe existants intacts"

title "Bannières (Lynis BANN-7126)"
backup_file_once /etc/issue
printf '%s\n' "${BANNER_MESSAGE}" > /etc/issue
cp -f /etc/issue /etc/issue.net
success "Bannières /etc/issue et /etc/issue.net"

title "Qualité exigée lors d'un changement de mot de passe"
tee /etc/security/pwquality.conf > /dev/null << EOF
minlen = ${PWQUALITY_MINLEN}
minclass = 3
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
retry = 3
EOF
success "pwquality minlen=${PWQUALITY_MINLEN} (pas 32 : desktop utilisable)"

if [[ -f /etc/pam.d/common-password ]] && ! grep -q "rounds=65536" /etc/pam.d/common-password; then
    sed -i 's/\(pam_unix\.so.*\)/\1 rounds=65536/' /etc/pam.d/common-password 2>/dev/null || true
fi

info "pam_faillock via pam-auth-update (ne pas sed common-auth)..."
tee /etc/security/faillock.conf > /dev/null << EOF
deny = ${FAILLOCK_DENY}
unlock_time = ${FAILLOCK_UNLOCK}
fail_interval = ${FAILLOCK_FAIL_INTERVAL}
# Ne pas verrouiller l'utilisateur courant trop agressivement (GDM).
even_deny_root
root_unlock_time = ${FAILLOCK_UNLOCK}
EOF
sed -i '/pam_faillock\.so/d' /etc/pam.d/common-auth /etc/pam.d/common-account 2>/dev/null || true
install -m 644 "${DIR_SCRIPT_PATH}/pam-configs/faillock" /usr/share/pam-configs/faillock
export DEBIAN_FRONTEND=noninteractive
pam-auth-update --force
pam-auth-update --enable faillock --force
success "pam_faillock configuré"

info "login.defs (UMASK, FAILLOG — PAS d'expiration des comptes existants)..."
if ! grep -q "^UMASK" /etc/login.defs; then
    echo "UMASK 027" >> /etc/login.defs
else
    sed -i 's/^#*UMASK.*/UMASK 027/' /etc/login.defs
fi
grep -q "^SHA_CRYPT_MIN_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MIN_ROUNDS 65536" >> /etc/login.defs
grep -q "^SHA_CRYPT_MAX_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MAX_ROUNDS 65536" >> /etc/login.defs
sed -i 's/^#*FAILLOG_ENAB.*/FAILLOG_ENAB yes/' /etc/login.defs
grep -q "^FAILLOG_ENAB" /etc/login.defs || echo "FAILLOG_ENAB yes" >> /etc/login.defs
# PASS_MAX_DAYS : ne PAS le baisser (forcerait un changement). On laisse la distro.
success "login.defs durci — aucun chage sur ${CURRENT_USER} / root"

info "UMASK 027 (pas de TMOUT : un desktop ne timeout pas le terminal)..."
if ! grep -q "^umask" /etc/profile; then
    echo "umask 027" >> /etc/profile
else
    sed -i 's/^#*umask.*/umask 027/' /etc/profile
fi
if ! grep -q "^umask" /etc/bash.bashrc; then
    echo "umask 027" >> /etc/bash.bashrc
else
    sed -i 's/^#*umask.*/umask 027/' /etc/bash.bashrc
fi
tee /etc/profile.d/hardening.sh > /dev/null << EOF
umask 027
EOF
chmod 644 /etc/profile.d/hardening.sh
success "UMASK 027"

info "sudo garde umask 0022 (apt/dpkg ne doivent pas créer des bibliothèques en 640)..."
# Sans umask_override, sudo unionne l'umask 027 de la session : les .so
# installées ensuite ne sont plus lisibles par libvirt-qemu ni par les jeux.
install -d -m 755 /etc/sudoers.d
cat > /etc/sudoers.d/high-fortress-user-umask << 'EOF'
# High-Fortress User — les paquets restent 644/755 malgré UMASK 027.
Defaults umask=0022
Defaults umask_override
EOF
chmod 440 /etc/sudoers.d/high-fortress-user-umask
if ! visudo -cf /etc/sudoers.d/high-fortress-user-umask >/dev/null; then
    rm -f /etc/sudoers.d/high-fortress-user-umask
    error "sudoers umask invalide — fichier retiré"
fi
success "sudoers : umask 0022 pour apt et les outils root"

title "journald persistant (Lynis LOG-*)"
ensure_dir /etc/systemd/journald.conf.d 755
tee /etc/systemd/journald.conf.d/persistent.conf > /dev/null << EOF
[Journal]
Storage=persistent
SystemMaxUse=512M
RuntimeMaxUse=64M
ForwardToSyslog=no
EOF
rm -f /etc/systemd/journald.conf.d/volatile.conf
run_silent systemctl restart systemd-journald
success "Journald persistant"

title "Sysctl workstation"
info "Paramètres sûrs pour navigateurs / Steam / KVM — pas d'IPv6 off, pas d'userns off..."

# Forwarding toujours à 1. libvirt ne le fige pas : NetworkManager et notre
# unité sysctl (After=libvirtd) réappliquent ce fichier. À 0, le NAT virbr0
# tombe dès qu'on installe QEMU après ce durcissement (wiki libvirt).
# rp_filter=2 (loose) : le mode strict jette le trafic retour des invités.
ip_forward=1
rp_filter=2
info "ip_forward=1 rp_filter=2 (NAT libvirt, que QEMU soit déjà présent ou non)"

tee /etc/sysctl.d/90-high-fortress-user.conf > /dev/null << EOF
# High-Fortress User — sysctl workstation Ubuntu 26.04
# Ne pas : disable IPv6, userns=0, ptrace_scope>1, ip_forward=0.
# Ne pas écrire kernel.apparmor_restrict_unprivileged_userns (défaut Ubuntu).

net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = ${rp_filter}
net.ipv4.conf.default.rp_filter = ${rp_filter}
net.ipv4.ip_forward = ${ip_forward}
net.ipv4.conf.all.forwarding = ${ip_forward}

net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# accept_ra laissé à la distro (Wi-Fi SLAAC desktop).

net.core.bpf_jit_harden = 2

kernel.sysrq = 0
kernel.unprivileged_bpf_disabled = 1
kernel.core_uses_pid = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
kernel.kexec_load_disabled = 1
fs.suid_dumpable = 0
fs.protected_fifos = 2
fs.protected_regular = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
dev.tty.ldisc_autoload = 0
EOF

cp -f /etc/sysctl.d/90-high-fortress-user.conf /etc/sysctl.d/99-zzz-high-fortress-user.conf
chmod 644 /etc/sysctl.d/90-high-fortress-user.conf /etc/sysctl.d/99-zzz-high-fortress-user.conf
sed "s|__HF_BASE__|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/hfu-sysctl.service" \
    > /etc/systemd/system/high-fortress-user-sysctl.service
run_silent systemctl daemon-reload
run_silent systemctl enable --now high-fortress-user-sysctl.service
run_silent sysctl --system
try_silent systemctl mask systemd-coredump.socket
success "Sysctl appliqué"

info "Permissions /etc/cron.d (Lynis FILE-7524)..."
chmod 700 /etc/cron.d
tee /etc/tmpfiles.d/high-fortress-user-cron.conf > /dev/null << 'EOF'
z /etc/cron.d 0700 root root -
EOF
success "/etc/cron.d mode 700"

info "Profil Lynis (exceptions desktop documentées)..."
mkdir -p /etc/lynis
tee /etc/lynis/custom.prf > /dev/null << 'EOF'
# High-Fortress User — exceptions volontaires workstation
# compilers : Proton / DXVK / gcc utilisateur
skip-test=HRDN-7222
# /tmp noexec : Electron, Steam, Firefox, Brave, Thunderbird
skip-test=FILE-6310
skip-test=FILE-6372
skip-test=FILE-6374
# mot de passe GRUB : peut enfermer un laptop
skip-test=BOOT-5122
# modules_disabled=1 : casserait kvm / nvidia / wifi après reboot
skip-test=KRNL-6000:kernel.modules_disabled
# forwarding : NAT libvirt (wiki : ip_forward figé à 1, même avant QEMU)
skip-test=KRNL-6000:net.ipv4.conf.all.forwarding
skip-test=KRNL-6000:net.ipv4.ip_forward
skip-test=KRNL-6000:net.ipv4.conf.all.rp_filter
# user namespaces : sandbox Firefox / Brave / Thunderbird / Steam / Electron
skip-test=KRNL-6000:kernel.unprivileged_userns_clone
# USB storage : desktop
skip-test=USB-1000
# expiration mots de passe : contrat — on ne change pas / n'expire pas les comptes
skip-test=AUTH-9282
skip-test=AUTH-9286
# PasswordAuthentication conservé (session desktop)
skip-test=SSH-7408
EOF
chmod 644 /etc/lynis/custom.prf
success "custom.prf Lynis posé"

title "Modules : protocoles et FS inutiles (on GARDE kvm, tun, overlay, usb)"
tee /etc/modprobe.d/disable-uncommon-protocols.conf > /dev/null << EOF
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF
success "dccp/sctp/rds/tipc blacklistés"

tee /etc/modprobe.d/disable-unused-fs.conf > /dev/null << 'EOF'
# Pas overlay/squashfs : snaps / flatpak / docker
# Pas usb-storage : desktop
install cramfs /bin/true
install freevxfs /bin/true
install hfs /bin/true
install hfsplus /bin/true
install jffs2 /bin/true
install udf /bin/true
blacklist cramfs
blacklist freevxfs
blacklist hfs
blacklist hfsplus
blacklist jffs2
blacklist udf
EOF
success "FS inutiles blacklistés"

title "KVM / QEMU — modules du processeur"
info "On ne force au boot que les modules qui se chargent sur ce CPU."
kvm_mods=()
cpu_vendor="$(awk '/^vendor_id/{print $3; exit}' /proc/cpuinfo 2>/dev/null || true)"
case "${cpu_vendor}" in
    GenuineIntel) kvm_candidates=(kvm kvm_intel vhost_net tun virtio_net virtio_pci) ;;
    AuthenticAMD|HygonGenuine) kvm_candidates=(kvm kvm_amd vhost_net tun virtio_net virtio_pci) ;;
    *) kvm_candidates=(kvm vhost_net tun virtio_net virtio_pci) ;;
esac
for m in "${kvm_candidates[@]}"; do
    if modprobe "${m}" 2>/dev/null; then
        kvm_mods+=("${m}")
    else
        info "module ${m} non chargeable sur cette machine"
    fi
done
if [[ ${#kvm_mods[@]} -gt 0 && " ${kvm_mods[*]} " == *" kvm "* ]]; then
    printf '%s\n' "${kvm_mods[@]}" > /etc/modules-load.d/kvm.conf
    chmod 644 /etc/modules-load.d/kvm.conf
    success "Modules KVM au boot : ${kvm_mods[*]}"
else
    rm -f /etc/modules-load.d/kvm.conf
    info "Pas de KVM matériel — aucun module KVM forcé au boot"
fi

title "Core dumps désactivés"
tee /etc/security/limits.d/90-disable-core.conf > /dev/null << EOF
* soft core 0
* hard core 0
EOF
success "limits core 0"

title "Initramfs"
info "update-initramfs -u (modules blacklist)..."
try_silent update-initramfs -u
success "Initramfs (best-effort)"

info "Compte ${CURRENT_USER} : mot de passe NON modifié, chage NON appliqué."
success "Configuration système workstation terminée"
