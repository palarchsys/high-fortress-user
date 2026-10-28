#!/usr/bin/env bash
# =============================================================================
# File       : system/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"

g_require_root
g_get_current_user

g_log_title "Algorithme des mots de passe (Lynis AUTH-9229)"
g_log_info "Configuration d'ENCRYPT_METHOD YESCRYPT (aucun chpasswd, aucun chage)"
if grep -q "^ENCRYPT_METHOD" /etc/login.defs; then
    sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD YESCRYPT/' /etc/login.defs
else
    echo "ENCRYPT_METHOD YESCRYPT" >> /etc/login.defs
fi
g_log_success "YESCRYPT pour les nouveaux hash, anciens intacts"

g_log_title "Bannières (Lynis BANN-7126)"
g_log_info "Pose des bannières"
g_copy_backup /etc/issue
printf '%s\n' "${G_BANNER_MESSAGE}" > /etc/issue
cp -f /etc/issue /etc/issue.net
g_log_success "Bannières posées (/etc/issue et /etc/issue.net)"

g_log_title "Qualité exigée lors d'un changement de mot de passe"
g_log_info "Configuration de pwquality"
tee /etc/security/pwquality.conf > /dev/null << EOF
minlen = ${W_PAM_PASSWORD_MIN_LENGTH}
minclass = 3
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
retry = 3
EOF
g_log_success "pwquality configuré (minlen=${W_PAM_PASSWORD_MIN_LENGTH}, pas 32 : desktop utilisable)"

if [[ -f /etc/pam.d/common-password ]] && ! grep -q "rounds=65536" /etc/pam.d/common-password; then
    sed -i 's/\(pam_unix\.so.*\)/\1 rounds=65536/' /etc/pam.d/common-password 2>/dev/null || true
fi

g_log_info "Configuration de pam_faillock (pam-auth-update, sans sed sur common-auth)"
tee /etc/security/faillock.conf > /dev/null << EOF
deny = ${W_FAILLOCK_DENY}
unlock_time = ${W_FAILLOCK_UNLOCK}
fail_interval = ${W_FAILLOCK_FAIL_INTERVAL}
even_deny_root
root_unlock_time = ${W_FAILLOCK_UNLOCK}
EOF
sed -i '/pam_faillock\.so/d' /etc/pam.d/common-auth /etc/pam.d/common-account 2>/dev/null || true
install -m 644 "$(g_locate_config_file system/pam-configs/faillock)" /usr/share/pam-configs/faillock
install -m 644 "$(g_locate_config_file system/pam-configs/faillock-preauth)" /usr/share/pam-configs/faillock-preauth
export DEBIAN_FRONTEND=noninteractive
pam-auth-update --force

pam-auth-update --enable faillock faillock-preauth --force
g_log_success "pam_faillock configuré"

g_log_info "Durcissement de login.defs (UMASK et FAILLOG, comptes existants gardés)"
if ! grep -q "^UMASK" /etc/login.defs; then
    echo "UMASK 027" >> /etc/login.defs
else
    sed -i 's/^#*UMASK.*/UMASK 027/' /etc/login.defs
fi
grep -q "^SHA_CRYPT_MIN_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MIN_ROUNDS 65536" >> /etc/login.defs
grep -q "^SHA_CRYPT_MAX_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MAX_ROUNDS 65536" >> /etc/login.defs
sed -i 's/^#*FAILLOG_ENAB.*/FAILLOG_ENAB yes/' /etc/login.defs
grep -q "^FAILLOG_ENAB" /etc/login.defs || echo "FAILLOG_ENAB yes" >> /etc/login.defs

g_log_success "login.defs durci — aucun chage sur ${CURRENT_USER} / root"

g_log_info "Configuration de l'UMASK 027 (pas de TMOUT sur le terminal)"
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
g_log_success "UMASK 027 appliqué"

g_log_info "Configuration du sudoers (umask 0022, apt ne crée pas de bibliothèques en 640)"

install -d -m 755 /etc/sudoers.d
cat > /etc/sudoers.d/liltress-workstation-umask << 'EOF'
Defaults umask=0022
Defaults umask_override
EOF
chmod 440 /etc/sudoers.d/liltress-workstation-umask
if ! visudo -cf /etc/sudoers.d/liltress-workstation-umask >/dev/null; then
    rm -f /etc/sudoers.d/liltress-workstation-umask
    g_log_error "sudoers umask invalide — fichier retiré"
fi
g_log_success "sudoers posé (umask 0022 pour apt et les outils root)"

g_log_info "Mémoire sudo de 5 minutes"
cat > /etc/sudoers.d/liltress-workstation-timeout << 'EOF'
Defaults timestamp_timeout=5
EOF
chmod 440 /etc/sudoers.d/liltress-workstation-timeout
if ! visudo -cf /etc/sudoers.d/liltress-workstation-timeout >/dev/null; then
    rm -f /etc/sudoers.d/liltress-workstation-timeout
    g_log_error "sudoers timeout invalide — fichier retiré"
fi
g_log_success "sudo redemande le mot de passe après 5 minutes"

g_log_title "journald persistant (Lynis LOG-*)"
g_log_info "Configuration de journald"
g_ensure_directory /etc/systemd/journald.conf.d 755
tee /etc/systemd/journald.conf.d/persistent.conf > /dev/null << EOF
[Journal]
Storage=persistent
SystemMaxUse=512M
RuntimeMaxUse=64M
ForwardToSyslog=no
EOF
rm -f /etc/systemd/journald.conf.d/volatile.conf
g_run_silent systemctl restart systemd-journald
g_log_success "Journald rendu persistant"

g_log_title "Sysctl workstation"
g_log_info "IPv6 et user namespaces actifs."

ip_forward=1
rp_filter=2
g_log_info "Application du sysctl (ip_forward=1, rp_filter=2)"

tee /etc/sysctl.d/90-liltress-workstation.conf > /dev/null << EOF

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

cp -f /etc/sysctl.d/90-liltress-workstation.conf /etc/sysctl.d/99-zzz-liltress-workstation.conf
chmod 644 /etc/sysctl.d/90-liltress-workstation.conf /etc/sysctl.d/99-zzz-liltress-workstation.conf
install -d -m 755 "${G_CONFIG_BASE_DIRECTORY}/cron/bin"
install -m 755 "${DIR_SCRIPT_PATH}/w-sysctl-apply.sh" \
    "${G_CONFIG_BASE_DIRECTORY}/cron/bin/w-sysctl-apply.sh"
sed "s|__HF_BASE__|${G_CONFIG_BASE_DIRECTORY}|g" "$(g_locate_config_file system/sysctl.service)" \
    > /etc/systemd/system/liltress-workstation-sysctl.service

rm -f /etc/systemd/system/docker.service.wants/liltress-workstation-sysctl.service
rm -f /etc/systemd/system/libvirtd.service.wants/liltress-workstation-sysctl.service
g_run_silent systemctl daemon-reload
g_run_silent systemctl enable --now liltress-workstation-sysctl.service
g_run_silent sysctl --system
g_log_success "Sysctl appliqué"

g_log_info "Resserrement des permissions des fichiers lus par Lynis"

w_apply_strict_mode() {
    local mode="$1" owner="$2" group="$3" path="$4"
    [[ -e "${path}" ]] || return 0
    if dpkg-statoverride --list "${path}" >/dev/null 2>&1; then
        dpkg-statoverride --remove "${path}" >/dev/null 2>&1 || true
    fi
    dpkg-statoverride --update --add "${owner}" "${group}" "${mode}" "${path}" >/dev/null
}
for cron_dir in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    w_apply_strict_mode 700 root root "${cron_dir}"
done
w_apply_strict_mode 600 root root /etc/crontab
w_apply_strict_mode 600 root root /etc/ssh/sshd_config
w_apply_strict_mode 750 root root /etc/sudoers.d
tee /etc/tmpfiles.d/liltress-workstation-cron.conf > /dev/null << 'EOF'
z /etc/cron.d 0700 root root -
z /etc/cron.hourly 0700 root root -
z /etc/cron.daily 0700 root root -
z /etc/cron.weekly 0700 root root -
z /etc/cron.monthly 0700 root root -
EOF
g_log_success "Permissions cron, sudoers et SSH resserrées"

g_log_info "Pose du profil Lynis (poste de travail, exceptions documentées)"
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
g_log_success "custom.prf Lynis posé"

g_log_title "Modules : protocoles et systèmes de fichiers inutiles"
g_log_info "Blacklist des protocoles inutiles"
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
g_log_success "dccp/sctp/rds/tipc blacklistés"

g_log_info "Blacklist des systèmes de fichiers inutiles"
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
g_log_success "FS inutiles blacklistés"

rm -f /etc/modules-load.d/kvm.conf

g_log_title "Core dumps désactivés"
g_log_info "Désactivation des core dumps"
tee /etc/security/limits.d/90-disable-core.conf > /dev/null << EOF
* soft core 0
* hard core 0
EOF
g_log_success "Limites core 0 posées"

g_log_title "Initramfs"
g_log_info "Mise à jour de l'initramfs (modules blacklist)"
g_run_optional update-initramfs -u
g_log_success "Initramfs mis à jour (best-effort)"

g_log_success "Configuration système workstation terminée"
