#!/usr/bin/env bash
# =============================================================================
# File       : system/configure.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"

require_root
detect_current_user

title "Algorithme des mots de passe (Lynis AUTH-9229)"
info "Configuration d'ENCRYPT_METHOD YESCRYPT (aucun chpasswd, aucun chage)"
if grep -q "^ENCRYPT_METHOD" /etc/login.defs; then
    sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD YESCRYPT/' /etc/login.defs
else
    echo "ENCRYPT_METHOD YESCRYPT" >> /etc/login.defs
fi
success "YESCRYPT pour les nouveaux hash, anciens intacts"

title "Bannières (Lynis BANN-7126)"
info "Pose des bannières"
backup_file_once /etc/issue
printf '%s\n' "${BANNER_MESSAGE}" > /etc/issue
cp -f /etc/issue /etc/issue.net
success "Bannières posées (/etc/issue et /etc/issue.net)"

title "Qualité exigée lors d'un changement de mot de passe"
info "Configuration de pwquality"
tee /etc/security/pwquality.conf > /dev/null << EOF
minlen = ${PWQUALITY_MINLEN}
minclass = 3
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
retry = 3
EOF
success "pwquality configuré (minlen=${PWQUALITY_MINLEN}, pas 32 : desktop utilisable)"

if [[ -f /etc/pam.d/common-password ]] && ! grep -q "rounds=65536" /etc/pam.d/common-password; then
    sed -i 's/\(pam_unix\.so.*\)/\1 rounds=65536/' /etc/pam.d/common-password 2>/dev/null || true
fi

info "Configuration de pam_faillock (pam-auth-update, sans sed sur common-auth)"
tee /etc/security/faillock.conf > /dev/null << EOF
deny = ${FAILLOCK_DENY}
unlock_time = ${FAILLOCK_UNLOCK}
fail_interval = ${FAILLOCK_FAIL_INTERVAL}
even_deny_root
root_unlock_time = ${FAILLOCK_UNLOCK}
EOF
sed -i '/pam_faillock\.so/d' /etc/pam.d/common-auth /etc/pam.d/common-account 2>/dev/null || true
install -m 644 "${DIR_SCRIPT_PATH}/pam-configs/faillock" /usr/share/pam-configs/faillock
install -m 644 "${DIR_SCRIPT_PATH}/pam-configs/faillock-preauth" /usr/share/pam-configs/faillock-preauth
export DEBIAN_FRONTEND=noninteractive
pam-auth-update --force

pam-auth-update --enable faillock faillock-preauth --force
success "pam_faillock configuré"

info "Durcissement de login.defs (UMASK et FAILLOG, comptes existants gardés)"
if ! grep -q "^UMASK" /etc/login.defs; then
    echo "UMASK 027" >> /etc/login.defs
else
    sed -i 's/^#*UMASK.*/UMASK 027/' /etc/login.defs
fi
grep -q "^SHA_CRYPT_MIN_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MIN_ROUNDS 65536" >> /etc/login.defs
grep -q "^SHA_CRYPT_MAX_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MAX_ROUNDS 65536" >> /etc/login.defs
sed -i 's/^#*FAILLOG_ENAB.*/FAILLOG_ENAB yes/' /etc/login.defs
grep -q "^FAILLOG_ENAB" /etc/login.defs || echo "FAILLOG_ENAB yes" >> /etc/login.defs

success "login.defs durci — aucun chage sur ${CURRENT_USER} / root"

info "Configuration de l'UMASK 027 (pas de TMOUT sur le terminal)"
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
success "UMASK 027 appliqué"

info "Configuration du sudoers (umask 0022, apt ne crée pas de bibliothèques en 640)"

install -d -m 755 /etc/sudoers.d
cat > /etc/sudoers.d/high-fortress-user-umask << 'EOF'
Defaults umask=0022
Defaults umask_override
EOF
chmod 440 /etc/sudoers.d/high-fortress-user-umask
if ! visudo -cf /etc/sudoers.d/high-fortress-user-umask >/dev/null; then
    rm -f /etc/sudoers.d/high-fortress-user-umask
    error "sudoers umask invalide — fichier retiré"
fi
success "sudoers posé (umask 0022 pour apt et les outils root)"

title "journald persistant (Lynis LOG-*)"
info "Configuration de journald"
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
success "Journald rendu persistant"

title "Sysctl workstation"
info "Navigateurs et Steam : IPv6 et user namespaces actifs."

ip_forward=1
rp_filter=2
info "Application du sysctl (ip_forward=1, rp_filter=2)"

tee /etc/sysctl.d/90-high-fortress-user.conf > /dev/null << EOF

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
net.ipv4.conf.all.proxy_arp = 0
net.ipv4.conf.default.proxy_arp = 0
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

net.core.bpf_jit_harden = 2

kernel.sysrq = 0
kernel.ctrl-alt-del = 0
kernel.unprivileged_bpf_disabled = 1
kernel.perf_event_paranoid = 3
kernel.randomize_va_space = 2
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
install -d -m 755 "${CONFIG_BASE_DIR}/cron/bin"
install -m 755 "${DIR_SCRIPT_PATH}/hfu-sysctl-apply.sh" \
    "${CONFIG_BASE_DIR}/cron/bin/hfu-sysctl-apply.sh"
sed "s|__HF_BASE__|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/hfu-sysctl.service" \
    > /etc/systemd/system/high-fortress-user-sysctl.service

rm -f /etc/systemd/system/docker.service.wants/high-fortress-user-sysctl.service
rm -f /etc/systemd/system/libvirtd.service.wants/high-fortress-user-sysctl.service
run_silent systemctl daemon-reload
run_silent systemctl enable --now high-fortress-user-sysctl.service
run_silent sysctl --system
success "Sysctl appliqué"

info "Resserrement des permissions des fichiers lus par Lynis"

hfu_strict_mode() {
    local mode="$1" owner="$2" group="$3" path="$4"
    [[ -e "${path}" ]] || return 0
    if dpkg-statoverride --list "${path}" >/dev/null 2>&1; then
        dpkg-statoverride --remove "${path}" >/dev/null 2>&1 || true
    fi
    dpkg-statoverride --update --add "${owner}" "${group}" "${mode}" "${path}" >/dev/null
}
for cron_dir in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    hfu_strict_mode 700 root root "${cron_dir}"
done
hfu_strict_mode 600 root root /etc/crontab
hfu_strict_mode 600 root root /etc/ssh/sshd_config
hfu_strict_mode 750 root root /etc/sudoers.d
hfu_strict_mode 640 root lp /etc/cups/cupsd.conf
tee /etc/tmpfiles.d/high-fortress-user-cron.conf > /dev/null << 'EOF'
z /etc/cron.d 0700 root root -
z /etc/cron.hourly 0700 root root -
z /etc/cron.daily 0700 root root -
z /etc/cron.weekly 0700 root root -
z /etc/cron.monthly 0700 root root -
EOF
success "Permissions cron, sudoers, SSH et CUPS resserrées"

info "Pose du profil Lynis (poste de travail, exceptions documentées)"
mkdir -p /etc/lynis
tee /etc/lynis/custom.prf > /dev/null << 'EOF'
machine-role=workstation
skip-test=HRDN-7222
skip-test=FILE-6310
skip-test=FILE-6372
skip-test=FILE-6374
skip-test=BOOT-5122
skip-test=KRNL-6000:kernel.modules_disabled
skip-test=KRNL-6000:net.ipv4.conf.all.forwarding
skip-test=KRNL-6000:net.ipv4.ip_forward
skip-test=KRNL-6000:net.ipv4.conf.all.rp_filter
skip-test=KRNL-6000:net.ipv4.conf.default.rp_filter
skip-test=KRNL-6000:kernel.unprivileged_userns_clone
skip-test=USB-1000
skip-test=AUTH-9282
skip-test=AUTH-9286
skip-test=SSH-7408
skip-test=TOOL-5002
skip-test=LOGG-2154
EOF
chmod 644 /etc/lynis/custom.prf
success "custom.prf Lynis posé"

title "Modules : protocoles et systèmes de fichiers inutiles"
info "Blacklist des protocoles inutiles"
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

info "Blacklist des systèmes de fichiers inutiles"
tee /etc/modprobe.d/disable-unused-fs.conf > /dev/null << 'EOF'
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

rm -f /etc/modules-load.d/kvm.conf

title "Core dumps désactivés"
info "Désactivation des core dumps"
tee /etc/security/limits.d/90-disable-core.conf > /dev/null << EOF
* soft core 0
* hard core 0
EOF
success "Limites core 0 posées"

title "Initramfs"
info "Mise à jour de l'initramfs (modules blacklist)"
try_silent update-initramfs -u
success "Initramfs mis à jour (best-effort)"

info "Compte ${CURRENT_USER} : mot de passe inchangé."
success "Configuration système workstation terminée"
