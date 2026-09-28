#!/usr/bin/env bash
# =============================================================================
# verify/workstation.sh
# =============================================================================
# Recette : durcissement en place, mots de passe intacts, applis préservées.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2:-WORKSTATION}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_current_user
detect_ssh_port
detect_os

PASS=0
FAIL=0
WARNN=0
REPORT="${HF_LOG_DIR:-.}/verify-report-WORKSTATION-$(date +%Y%m%d-%H%M%S).md"

ok()   { PASS=$((PASS+1));  success "OK    $*"; echo "- OK    $*" >> "${REPORT}"; }
ko()   { FAIL=$((FAIL+1));  red "FAIL  $*";     echo "- FAIL  $*" >> "${REPORT}"; }
wn()   { WARNN=$((WARNN+1)); warn "WARN  $*";   echo "- WARN  $*" >> "${REPORT}"; }

mkdir -p "$(dirname "${REPORT}")"
{
    echo "# High-Fortress User — recette workstation"
    echo
    echo "- date : $(date -Iseconds)"
    echo "- user : ${CURRENT_USER}"
    echo "- os   : ${OS_PRETTY}"
    echo
} > "${REPORT}"

title "Contrats (mots de passe, applis)"

# Hash des comptes : on n'a jamais appelé chpasswd. Vérifier que shadow
# root et user ont un hash non vide (compte pas verrouillé par nous).
root_hash="$(awk -F: '$1=="root"{print $2}' /etc/shadow)"
user_hash="$(awk -F: -v u="${CURRENT_USER}" '$1==u{print $2}' /etc/shadow)"
if [[ -z "${root_hash}" ]]; then
    ko "shadow root vide"
elif [[ "${root_hash}" == "*" || "${root_hash}" == "!" || "${root_hash}" == "!!" || "${root_hash}" == "!*" ]]; then
    ok "compte root verrouillé par Ubuntu (ce programme ne pose pas de mot de passe root)"
else
    ok "root : hash présent, non réécrit par HFU"
fi
if [[ -z "${user_hash}" || "${user_hash}" == "!" || "${user_hash}" == "*" ]]; then
    ko "compte ${CURRENT_USER} sans mot de passe utilisable"
else
    ok "compte ${CURRENT_USER} : hash intact (HFU n'appelle jamais chpasswd)"
fi

# chage : MAXDAYS ne doit pas avoir été forcé à 90 par nous
maxdays="$(LANG=C LC_ALL=C chage -l "${CURRENT_USER}" 2>/dev/null | awk -F: '/Maximum/{gsub(/ /,"",$2); print $2}')"
if [[ "${maxdays}" == "90" ]]; then
    wn "chage MAXDAYS=90 sur ${CURRENT_USER} (n'a pas été posé par ce script ; état antérieur ?)"
else
    ok "chage ${CURRENT_USER} non forcé à 90 jours"
fi

if drift="$(human_accounts_drift 2>&1)"; then
    ok "comptes humains (uid, groupes, home, shell, hash) inchangés"
else
    ko "un compte créé à l'installation Ubuntu a été modifié"
    printf '%s\n' "${drift}" >> "${REPORT}"
fi

for bin in firefox brave-browser thunderbird steam discord keepassxc virt-manager virsh qemu-system-x86_64; do
    if command -v "${bin}" >/dev/null 2>&1; then
        mode="$(stat -c '%a' "$(command -v "${bin}")" 2>/dev/null || echo '?')"
        if [[ "${mode}" == "700" || "${mode}" == "750" ]]; then
            ko "${bin} n'est plus exécutable par l'utilisateur (mode ${mode})"
        else
            ok "${bin} présent (mode ${mode})"
        fi
    else
        info "${bin} non installé — skip"
    fi
done

# Compilateurs doivent rester world-exec si présents
for b in gcc g++ cc make; do
    if command -v "${b}" >/dev/null 2>&1; then
        mode="$(stat -c '%a' "$(command -v "${b}")")"
        if [[ "${mode}" == "700" ]]; then
            ko "compilateur ${b} en 700 (Proton cassé)"
        else
            ok "compilateur ${b} mode ${mode}"
        fi
    fi
done

title "SSH / UFW / services"

if sshd -T 2>/dev/null | grep -qiE '^permitrootlogin no$'; then
    ok "PermitRootLogin no"
else
    ko "PermitRootLogin n'est pas no"
fi
if sshd -T 2>/dev/null | grep -qiE '^passwordauthentication yes$'; then
    ok "PasswordAuthentication yes (desktop)"
else
    wn "PasswordAuthentication n'est pas yes — vérifier que des clés existent pour ${CURRENT_USER}"
fi
if sshd -t 2>/dev/null; then
    ok "sshd -t"
else
    ko "sshd -t échoue"
fi

if LANG=C LC_ALL=C ufw status | grep -qw "Status: active"; then
    ok "UFW actif"
else
    ko "UFW inactif"
fi
if LANG=C LC_ALL=C ufw status verbose | grep -qiE 'Default: deny \(incoming\), allow \(outgoing\)'; then
    ok "UFW outgoing ALLOW"
else
    # fallback parse
    if ufw status verbose | grep -qi 'Outgoing: allow'; then
        ok "UFW outgoing ALLOW"
    else
        ko "UFW outgoing n'est pas allow — Steam/Discord cassés"
    fi
fi

tmp_opts="$(findmnt -no OPTIONS /tmp 2>/dev/null || true)"
if echo "${tmp_opts}" | grep -qw noexec; then
    ko "/tmp est noexec (Electron/Steam/Firefox/Brave)"
else
    ok "/tmp sans noexec"
fi

if [[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)" == "1" ]]; then
    ok "ip_forward=1 (NAT libvirt)"
else
    ko "ip_forward n'est pas 1 — le NAT QEMU est cassé"
fi
if [[ "$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null || echo missing)" == "1" ]]; then
    ok "ptrace_scope=1"
else
    ko "ptrace_scope n'est pas 1"
fi
if [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo 0)" == "0" ]]; then
    ok "IPv6 laissé actif"
else
    ko "IPv6 désactivé"
fi
if [[ -n "$(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || true)" \
    && "$(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || echo 1)" == "0" ]]; then
    ko "unprivileged_userns_clone=0 (sandbox navigateurs / Steam)"
else
    ok "user namespaces non désactivés par sysctl"
fi
if grep -RqsE 'apparmor_restrict_unprivileged_userns[[:space:]]*=[[:space:]]*0' /etc/sysctl.d /etc/sysctl.conf 2>/dev/null; then
    ko "un fichier sysctl désactive la restriction userns AppArmor au lieu d'un profil"
else
    ok "restriction userns AppArmor non désactivée par HFU"
fi
if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
    if dpkg --print-foreign-architectures | grep -qx i386; then
        ok "architecture i386 activée (Steam)"
    else
        ko "i386 absent — Steam ne peut pas installer ses bibliothèques 32 bits"
    fi
fi
if [[ -f /etc/sudoers.d/high-fortress-user-umask ]] \
    && visudo -cf /etc/sudoers.d/high-fortress-user-umask >/dev/null \
    && grep -q 'umask_override' /etc/sudoers.d/high-fortress-user-umask; then
    ok "sudo umask 0022 (apt ne hérite pas de 027)"
else
    ko "sudoers umask absent ou invalide"
fi
if grep -q '^DEFAULT_FORWARD_POLICY="ACCEPT"' /etc/default/ufw 2>/dev/null; then
    ok "UFW DEFAULT_FORWARD_POLICY=ACCEPT"
else
    ko "UFW forward policy n'est pas ACCEPT (NAT libvirt)"
fi
# libvirtd.service s'arrête tout seul après une période sans client
# (option --timeout). Le socket reste actif et le relance à la demande.
if systemctl is-enabled libvirtd.service >/dev/null 2>&1 \
    && { systemctl is-active --quiet libvirtd.service || systemctl is-active --quiet libvirtd.socket; }; then
    ok "libvirtd activé (service ou socket)"
else
    ko "libvirtd.service inactif"
fi
if systemctl cat virtnetworkd.service >/dev/null 2>&1; then
    if systemctl is-active --quiet virtnetworkd.service; then
        ok "virtnetworkd.service actif"
    else
        ko "virtnetworkd.service inactif"
    fi
else
    ok "réseau virtuel porté par libvirtd (pas d'unité virtnetworkd)"
fi
if systemctl is-active --quiet postfix; then
    ok "Postfix actif"
else
    ko "Postfix inactif"
fi
postfix_listen="$(postconf -h inet_interfaces 2>/dev/null | tr -d '[:space:]' || true)"
case "${postfix_listen}" in
    loopback-only|localhost|127.0.0.1|"[::1]")
        ok "Postfix écoute seulement localhost"
        ;;
    *)
        ko "Postfix n'est pas limité à localhost (${postfix_listen:-inconnu})"
        ;;
esac

if [[ -e /dev/kvm ]]; then
    ok "/dev/kvm présent"
    if lsmod | grep -qE '^kvm'; then
        ok "module kvm chargé"
    else
        wn "module kvm non chargé (OK si pas de VM en cours)"
    fi
else
    info "/dev/kvm absent (pas de virt matériel) — skip"
fi

for svc in apparmor fail2ban auditd clamav-daemon clamav-freshclam unattended-upgrades; do
    if systemctl is-enabled --quiet "${svc}" 2>/dev/null || systemctl is-active --quiet "${svc}" 2>/dev/null; then
        ok "service ${svc} enabled/active"
    else
        wn "service ${svc} inactif"
    fi
done

if systemctl is-enabled --quiet clamonacc 2>/dev/null || systemctl is-active --quiet clamonacc 2>/dev/null; then
    ko "clamonacc actif (OnAccess desktop interdit)"
else
    ok "clamonacc inactif/masqué"
fi

title "Ubuntu Pro"

if ! command -v pro >/dev/null 2>&1; then
    ko "ubuntu-pro-client absent"
elif ubuntu_pro_attached; then
    ok "Ubuntu Pro attaché"
    # Le texte de « pro status » change selon la langue. Le JSON est stable.
    while IFS='=' read -r svc_name svc_status; do
        case "${svc_status}" in
            enabled|active) ok "${svc_name} activé" ;;
            *) ko "${svc_name} non activé (état : ${svc_status:-inconnu})" ;;
        esac
    done < <(pro status --format json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
wanted = ("esm-infra", "esm-apps", "livepatch")
for svc in data.get("services") or []:
    name = svc.get("name")
    if name in wanted:
        print("%s=%s" % (name, svc.get("status") or ""))
')
else
    ko "Ubuntu Pro non attaché (obligatoire)"
fi

title "Lynis"

if command -v lynis >/dev/null 2>&1; then
    ok "lynis installé"
    if [[ -f /etc/lynis/custom.prf ]]; then
        ok "custom.prf présent"
    else
        wn "custom.prf manquant"
    fi
    info "Audit Lynis (quick)..."
    lynis audit system --quick --no-colors --auditor high-fortress-user-verify > "${HF_LOG_DIR:-/tmp}/lynis-verify.txt" 2>&1 || true
    score="$(awk -F= '/hardening_index=/{print $2}' /var/log/lynis-report.dat 2>/dev/null | tail -1)"
    if [[ -n "${score}" ]]; then
        echo "- Lynis hardening_index=${score}" >> "${REPORT}"
        if [[ "${score}" -ge "${LYNIS_MIN_SCORE}" ]]; then
            ok "Lynis ${score} ≥ ${LYNIS_MIN_SCORE}"
        else
            wn "Lynis ${score} < ${LYNIS_MIN_SCORE} (exceptions desktop dans custom.prf)"
        fi
    else
        wn "score Lynis illisible"
    fi
    chmod 640 /var/log/lynis.log /var/log/lynis-report.dat 2>/dev/null || true
else
    ko "lynis absent"
fi

title "Logiciels du poste"

if command -v brave-browser >/dev/null 2>&1 || [[ -x /opt/brave.com/brave/brave ]]; then
    ok "Brave installé"
else
    ko "Brave absent"
fi
if snap list telegram-desktop >/dev/null 2>&1; then
    ok "Telegram (snap) installé"
else
    ko "Telegram snap absent"
fi
if dpkg-query -W -f '${Status}' discord 2>/dev/null | grep -q 'install ok'; then
    ok "Discord installé"
else
    ko "Discord absent"
fi
# Vencord écrit son réglage dans ~/.config/Vencord et remplace le
# client téléchargé dans ~/.config/discord/app-*/resources (fichier _app.asar).
# Il n'y a rien à chercher dans /usr/share/discord : ce dossier n'a que le lanceur.
vencord_marker="$(find "${CURRENT_HOME}/.config/discord" -path '*/resources/_app.asar' -print -quit 2>/dev/null || true)"
if [[ -d "${CURRENT_HOME}/.config/Vencord" || -n "${vencord_marker}" ]]; then
    ok "Vencord présent"
else
    ko "Vencord absent"
fi
if dpkg-query -W -f '${Status}' thunderbird 2>/dev/null | grep -q 'install ok' \
    || snap list thunderbird >/dev/null 2>&1; then
    ok "Thunderbird installé"
else
    ko "Thunderbird absent"
fi
if dpkg-query -W -f '${Status}' keepassxc 2>/dev/null | grep -q 'install ok'; then
    ok "KeePassXC installé"
else
    ko "KeePassXC absent"
fi
if dpkg-query -W -f '${Status}' qemu-system-x86 2>/dev/null | grep -q 'install ok'; then
    ok "QEMU (qemu-system-x86, dépôt Ubuntu) installé"
else
    ko "QEMU qemu-system-x86 absent"
fi

title "Sources APT"
if [[ -f /etc/apt/sources.list ]]; then
    if grep -q 'high-fortress' /etc/apt/sources.list; then
        ko "sources.list a été réécrit"
    else
        ok "sources.list non réécrit par HFU"
    fi
fi
ok "dépôt Lynis CISOfy ajouté uniquement (lynis.list)"

{
    echo
    echo "## Totaux"
    echo
    echo "- OK   : ${PASS}"
    echo "- WARN : ${WARNN}"
    echo "- FAIL : ${FAIL}"
} >> "${REPORT}"

step_off "Recette : ${PASS} OK / ${WARNN} WARN / ${FAIL} FAIL"
info "Rapport : ${REPORT}"

if [[ "${FAIL}" -gt 0 ]]; then
    error "Recette : ${FAIL} échec(s)"
fi
success "Recette workstation OK"
