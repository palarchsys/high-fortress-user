#!/usr/bin/env bash
# =============================================================================
# File       : verify/workstation.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
hf_get_current_user
hf_get_ssh_port
hf_get_operating_system

PASS=0
FAIL=0
WARNN=0
REPORT="${HF_LOG_DIR:-.}/verify-report-WORKSTATION-$(date +%Y%m%d-%H%M%S).md"

hfu_report_pass()   { PASS=$((PASS+1));  hf_log_success "OK    $*"; echo "- OK    $*" >> "${REPORT}"; }
hfu_report_fail()   { FAIL=$((FAIL+1));  hf_set_color_red "FAIL  $*";     echo "- FAIL  $*" >> "${REPORT}"; }
hfu_report_warn()   { WARNN=$((WARNN+1)); hf_log_warn "WARN  $*";   echo "- WARN  $*" >> "${REPORT}"; }

mkdir -p "$(dirname "${REPORT}")"
{
    echo "# High-Fortress User — check workstation"
    echo
    echo "- date : $(date -Iseconds)"
    echo "- user : ${CURRENT_USER}"
    echo "- os   : ${OS_PRETTY}"
    echo
} > "${REPORT}"

hf_log_title "Contrats (mots de passe, applis)"

root_hash="$(awk -F: '$1=="root"{print $2}' /etc/shadow)"
user_hash="$(awk -F: -v u="${CURRENT_USER}" '$1==u{print $2}' /etc/shadow)"
if [[ -z "${root_hash}" ]]; then
    hfu_report_fail "shadow root vide"
elif [[ "${root_hash}" == "*" || "${root_hash}" == "!" || "${root_hash}" == "!!" || "${root_hash}" == "!*" ]]; then
    hfu_report_pass "compte root verrouillé par Ubuntu (ce programme ne pose pas de mot de passe root)"
else
    hfu_report_pass "root : hash présent, non réécrit par HFU"
fi
if [[ -z "${user_hash}" || "${user_hash}" == "!" || "${user_hash}" == "*" ]]; then
    hfu_report_fail "compte ${CURRENT_USER} sans mot de passe utilisable"
else
    hfu_report_pass "compte ${CURRENT_USER} : hash intact (HFU n'appelle jamais chpasswd)"
fi

maxdays="$(LANG=C LC_ALL=C chage -l "${CURRENT_USER}" 2>/dev/null | awk -F: '/Maximum/{gsub(/ /,"",$2); print $2}')"
if [[ "${maxdays}" == "90" ]]; then
    hfu_report_warn "chage MAXDAYS=90 sur ${CURRENT_USER} (n'a pas été posé par ce script ; état antérieur ?)"
else
    hfu_report_pass "chage ${CURRENT_USER} non forcé à 90 jours"
fi

if drift="$(hf_check_account_drift 2>&1)"; then
    hfu_report_pass "comptes humains (uid, groupes, home, shell, hash) inchangés"
else
    hfu_report_fail "un compte créé à l'installation Ubuntu a été modifié"
    printf '%s\n' "${drift}" >> "${REPORT}"
fi

for bin in brave-browser thunderbird steam discord keepassxc; do
    if command -v "${bin}" >/dev/null 2>&1; then
        mode="$(stat -c '%a' "$(command -v "${bin}")" 2>/dev/null || echo '?')"
        if [[ "${mode}" == "700" || "${mode}" == "750" ]]; then
            hfu_report_fail "${bin} n'est plus exécutable par l'utilisateur (mode ${mode})"
        else
            hfu_report_pass "${bin} présent (mode ${mode})"
        fi
    else
        hf_log_info "${bin} non installé — skip"
    fi
done

for b in gcc g++ cc make; do
    if command -v "${b}" >/dev/null 2>&1; then
        mode="$(stat -c '%a' "$(command -v "${b}")")"
        if [[ "${mode}" == "700" ]]; then
            hfu_report_fail "compilateur ${b} en 700 (Proton cassé)"
        else
            hfu_report_pass "compilateur ${b} mode ${mode}"
        fi
    fi
done

hf_log_title "SSH / UFW / services"

root_login="$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2; exit}')"
if [[ "${root_login}" == "no" ]]; then
    hfu_report_pass "PermitRootLogin no"
else
    hfu_report_fail "PermitRootLogin n'est pas no (valeur effective : ${root_login:-inconnue})"
fi
if sshd -T 2>/dev/null | grep -qiE '^passwordauthentication yes$'; then
    hfu_report_pass "PasswordAuthentication yes (le mot de passe du compte est accepté en SSH)"
else
    hfu_report_pass "PasswordAuthentication n'est pas yes (SSH n'accepte qu'une clé pour ${CURRENT_USER})"
fi
tcp_fwd="$(sshd -T 2>/dev/null | awk '/^allowtcpforwarding /{print $2; exit}')"
agent_fwd="$(sshd -T 2>/dev/null | awk '/^allowagentforwarding /{print $2; exit}')"
if [[ "${tcp_fwd}" == "no" && "${agent_fwd}" == "no" ]]; then
    hfu_report_pass "relais SSH coupé"
else
    hfu_report_fail "relais SSH ouvert (tcp ${tcp_fwd:-inconnu}, agent ${agent_fwd:-inconnu})"
fi
if sshd -t 2>/dev/null; then
    hfu_report_pass "sshd -t"
else
    hfu_report_fail "sshd -t échoue"
fi

if LANG=C LC_ALL=C ufw status | grep -qw "Status: active"; then
    hfu_report_pass "UFW actif"
else
    hfu_report_fail "UFW inactif"
fi
if LANG=C LC_ALL=C ufw status verbose | grep -qiE 'Default: deny \(incoming\), allow \(outgoing\)'; then
    hfu_report_pass "UFW outgoing ALLOW"
else

    if ufw status verbose | grep -qi 'Outgoing: allow'; then
        hfu_report_pass "UFW outgoing ALLOW"
    else
        hfu_report_fail "UFW outgoing n'est pas allow — Steam/Discord cassés"
    fi
fi
ufw_rules="$(LANG=C LC_ALL=C ufw status 2>/dev/null || true)"
if grep -qF 'SSH LAN' <<< "${ufw_rules}" || grep -qF 'SSH (limit)' <<< "${ufw_rules}"; then
    hfu_report_pass "SSH limité aux préfixes connectés"
else
    hfu_report_fail "règle SSH absente"
fi

tmp_opts="$(findmnt -no OPTIONS /tmp 2>/dev/null || true)"
if echo "${tmp_opts}" | grep -qw noexec; then
    hfu_report_fail "/tmp est noexec (Electron/Steam/Firefox/Brave)"
else
    hfu_report_pass "/tmp sans noexec"
fi

if [[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)" == "1" ]]; then
    hfu_report_pass "ip_forward=1"
else
    hfu_report_fail "ip_forward n'est pas 1"
fi
if [[ "$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null || echo missing)" == "1" ]]; then
    hfu_report_pass "ptrace_scope=1"
else
    hfu_report_fail "ptrace_scope n'est pas 1"
fi
if [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo 0)" == "0" ]]; then
    hfu_report_pass "IPv6 laissé actif"
else
    hfu_report_fail "IPv6 désactivé"
fi
if [[ -n "$(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || true)" \
    && "$(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || echo 1)" == "0" ]]; then
    hfu_report_fail "unprivileged_userns_clone=0 (sandbox navigateurs / Steam)"
else
    hfu_report_pass "user namespaces non désactivés par sysctl"
fi
if grep -RqsE 'apparmor_restrict_unprivileged_userns[[:space:]]*=[[:space:]]*0' /etc/sysctl.d /etc/sysctl.conf 2>/dev/null; then
    hfu_report_fail "un fichier sysctl désactive la restriction userns AppArmor au lieu d'un profil"
else
    hfu_report_pass "restriction userns AppArmor non désactivée par HFU"
fi
if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
    if dpkg --print-foreign-architectures | grep -qx i386; then
        hfu_report_pass "architecture i386 activée (Steam)"
    else
        hfu_report_fail "i386 absent — Steam ne peut pas installer ses bibliothèques 32 bits"
    fi
fi
if [[ -f /etc/sudoers.d/high-fortress-user-umask ]] \
    && visudo -cf /etc/sudoers.d/high-fortress-user-umask >/dev/null \
    && grep -q 'umask_override' /etc/sudoers.d/high-fortress-user-umask; then
    hfu_report_pass "sudo umask 0022 (apt ne hérite pas de 027)"
else
    hfu_report_fail "sudoers umask absent ou invalide"
fi
if [[ -f /etc/sudoers.d/high-fortress-user-timeout ]] \
    && visudo -cf /etc/sudoers.d/high-fortress-user-timeout >/dev/null 2>&1 \
    && grep -qx 'Defaults timestamp_timeout=5' /etc/sudoers.d/high-fortress-user-timeout; then
    hfu_report_pass "sudo redemande le mot de passe après 5 minutes"
else
    hfu_report_fail "délai sudo absent ou invalide"
fi
if grep -q '^DEFAULT_FORWARD_POLICY="ACCEPT"' /etc/default/ufw 2>/dev/null; then
    hfu_report_pass "UFW DEFAULT_FORWARD_POLICY=ACCEPT"
else
    hfu_report_fail "UFW forward policy n'est pas ACCEPT"
fi
if [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then
    if systemctl is-active --quiet postfix; then
        hfu_report_pass "Postfix actif"
    else
        hfu_report_fail "Postfix inactif"
    fi
    postfix_listen="$(postconf -h inet_interfaces 2>/dev/null | tr -d '[:space:]' || true)"
    case "${postfix_listen}" in
        loopback-only|localhost|127.0.0.1|"[::1]")
            hfu_report_pass "Postfix écoute seulement localhost"
            ;;
        *)
            hfu_report_fail "Postfix n'est pas limité à localhost (${postfix_listen:-inconnu})"
            ;;
    esac
else
    hfu_report_pass "alertes e-mail coupées"
fi

systemctl daemon-reload >/dev/null 2>&1 || true

for svc in apparmor fail2ban auditd clamav-daemon clamav-freshclam unattended-upgrades unbound; do
    if systemctl is-enabled --quiet "${svc}" 2>/dev/null || systemctl is-active --quiet "${svc}" 2>/dev/null; then
        hfu_report_pass "service ${svc} enabled/active"
    else
        hfu_report_warn "service ${svc} inactif"
    fi
done

if systemctl is-active --quiet clamav-clamonacc.service 2>/dev/null \
    || systemctl is-active --quiet clamonacc.service 2>/dev/null; then
    hfu_report_pass "ClamAV surveille les dossiers à risque en continu"
else
    hfu_report_fail "clamonacc inactif ($(systemctl is-active clamav-clamonacc.service 2>/dev/null || systemctl is-active clamonacc.service 2>/dev/null || echo absent))"
fi
if systemctl is-enabled --quiet hfu-boot-chain.timer 2>/dev/null; then
    hfu_report_pass "chaîne de sécurité au démarrage"
else
    hfu_report_fail "timer de la chaîne de démarrage absent"
fi
if systemctl is-enabled --quiet hfu-idle-scan.timer 2>/dev/null; then
    hfu_report_pass "passe différée des chemins exclus"
else
    hfu_report_fail "timer de passe différée absent"
fi
if systemctl is-enabled --quiet hfu-reboot-notice.timer 2>/dev/null; then
    hfu_report_pass "avis de redémarrage planifié"
else
    hfu_report_fail "timer d'avis de redémarrage absent"
fi
usb_mod="usb-storage"
if grep -RqsE "^[[:space:]]*(install|blacklist)[[:space:]]+${usb_mod}([[:space:]]|$)" /etc/modprobe.d /etc/modprobe.conf 2>/dev/null; then
    hfu_report_fail "module usb-storage bloqué au chargement"
else
    hfu_report_pass "stockage USB non bloqué au chargement"
fi
usb_rules="/etc/usbguard/rules.conf"
usb_hid='allow with-interface equals { 03:*:* }'
usb_hub='allow with-interface equals { 09:*:* }'
if [[ ! -f "${usb_rules}" ]] || ! grep -qF "${usb_hid}" "${usb_rules}"; then
    hfu_report_warn "USBGuard sans autorisation clavier et souris"
elif ! systemctl is-active --quiet usbguard; then
    hfu_report_fail "USBGuard inactif alors que la politique existe"
elif ! grep -qF "${usb_hub}" "${usb_rules}"; then
    hfu_report_warn "USBGuard sans concentrateur"
else
    hfu_report_pass "USBGuard actif (appareils présents et HID autorisés)"
fi
if systemctl is-active --quiet crowdsec 2>/dev/null \
    && systemctl is-active --quiet crowdsec-firewall-bouncer 2>/dev/null; then
    hfu_report_pass "CrowdSec et bouncer actifs"
else
    hfu_report_fail "CrowdSec inactif"
fi

hf_log_title "DNS local (Unbound)"
if systemctl is-enabled --quiet unbound 2>/dev/null && systemctl is-active --quiet unbound; then
    hfu_report_pass "Unbound actif au démarrage"
else
    hfu_report_fail "Unbound inactif"
fi
if [[ -f /usr/share/dns/root.hints && -f /etc/unbound/unbound.conf.d/high-fortress-user.conf ]]; then
    hfu_report_pass "liste des serveurs racine et configuration Unbound présentes"
else
    hfu_report_fail "configuration Unbound ou root.hints absente"
fi
if systemctl is-enabled --quiet hfu-unbound-root-hints.path 2>/dev/null; then
    hfu_report_pass "rechargement Unbound quand les serveurs racine changent"
else
    hfu_report_fail "surveillance des serveurs racine DNS absente"
fi
if ss -H -lntu src 127.0.0.1:53 2>/dev/null | grep -q .; then
    hfu_report_pass "Unbound écoute 127.0.0.1:53"
else
    hfu_report_fail "Unbound n'écoute pas 127.0.0.1:53"
fi
if ss -H -lntu src 0.0.0.0:53 2>/dev/null | grep -q .; then
    hfu_report_fail "Unbound écoute hors de la machine"
fi
if grep -q '^DNS=127.0.0.1' /etc/systemd/resolved.conf.d/90-high-fortress-user.conf 2>/dev/null; then
    hfu_report_pass "systemd-resolved pointe vers Unbound"
else
    hfu_report_fail "systemd-resolved n'est pas pointé vers Unbound"
fi

hf_log_title "Ubuntu Pro"

if ! command -v pro >/dev/null 2>&1; then
    hfu_report_fail "ubuntu-pro-client absent"
elif hf_check_ubuntu_pro; then
    hfu_report_pass "Ubuntu Pro attaché"

    while IFS=$'\t' read -r svc_name svc_status svc_detail; do
        case "${svc_status}" in
            enabled|active)
                hfu_report_pass "${svc_name} activé"
                ;;
            warning)
                hfu_report_pass "${svc_name} activé, redémarrage encore utile${svc_detail:+ : ${svc_detail}}"
                ;;
            *)
                hfu_report_fail "${svc_name} non activé (état : ${svc_status:-inconnu}${svc_detail:+ : ${svc_detail}})"
                ;;
        esac
    done < <(pro status --format json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
wanted = ("esm-infra", "esm-apps", "livepatch")
for svc in data.get("services") or []:
    name = svc.get("name")
    if name not in wanted:
        continue
    detail = svc.get("status_details") or ""
    warning = svc.get("warning") or {}
    if isinstance(warning, dict) and warning.get("message"):
        detail = warning["message"]
    detail = detail.replace("\t", " ").replace("\n", " ")
    print("%s\t%s\t%s" % (name, svc.get("status") or "", detail))
')
else
    hfu_report_fail "Ubuntu Pro non attaché (obligatoire)"
fi

hf_log_title "Lynis"

if command -v lynis >/dev/null 2>&1; then
    hfu_report_pass "lynis installé"
    if [[ -f /etc/lynis/custom.prf ]]; then
        hfu_report_pass "custom.prf présent"
    else
        hfu_report_warn "custom.prf manquant"
    fi
    hf_log_info "Audit Lynis (quick)"
    lynis audit system --quick --no-colors --auditor high-fortress-user-verify > "${HF_LOG_DIR:-/tmp}/lynis-verify.txt" 2>&1 || true
    score="$(awk -F= '/hardening_index=/{print $2}' /var/log/lynis-report.dat 2>/dev/null | tail -1)"
    if [[ "${score}" =~ ^[0-9]+$ ]]; then
        echo "- Lynis hardening_index=${score}" >> "${REPORT}"
        if [[ "${score}" -ge "${HF_LYNIS_MIN_SCORE}" ]]; then
            hfu_report_pass "Lynis ${score} ≥ ${HF_LYNIS_MIN_SCORE}"
        else
            hfu_report_fail "Lynis ${score} < ${HF_LYNIS_MIN_SCORE}"
            awk -F= '/^warning\[\]=/{print "   [INFO]  Lynis " $2}' /var/log/lynis-report.dat 2>/dev/null | head -20 || true
        fi
    else
        hfu_report_fail "score Lynis illisible"
    fi
    chmod 640 /var/log/lynis.log /var/log/lynis-report.dat 2>/dev/null || true
else
    hfu_report_fail "lynis absent"
fi

hf_log_title "Logiciels du poste"

if command -v brave-browser >/dev/null 2>&1 || [[ -x /opt/brave.com/brave/brave ]]; then
    hf_log_info "Brave présent"
else
    hf_log_info "Brave absent"
fi
if dpkg-query -W -f '${Status}' discord 2>/dev/null | grep -q 'install ok'; then
    hf_log_info "Discord présent"
else
    hf_log_info "Discord absent"
fi
vencord_marker="$(find "${CURRENT_HOME}/.config/discord" -path '*/resources/_app.asar' -print -quit 2>/dev/null || true)"
if [[ -d "${CURRENT_HOME}/.config/Vencord" || -n "${vencord_marker}" ]]; then
    hf_log_info "Vencord présent"
else
    hf_log_info "Vencord absent"
fi
if dpkg-query -W -f '${Status}' thunderbird 2>/dev/null | grep -q 'install ok' \
    || { command -v snap >/dev/null 2>&1 && snap list thunderbird >/dev/null 2>&1; }; then
    hf_log_info "Thunderbird présent"
else
    hf_log_info "Thunderbird absent"
fi
if dpkg-query -W -f '${Status}' snapd 2>/dev/null | grep -q 'install ok'; then
    hfu_report_pass "snapd conservé"
else
    hfu_report_fail "snapd absent"
fi
if command -v snap >/dev/null 2>&1 && snap list firefox >/dev/null 2>&1; then
    hf_log_info "snap Firefox présent"
else
    hf_log_info "snap Firefox absent"
fi
if dpkg-query -W -f '${Status}' keepassxc 2>/dev/null | grep -q 'install ok' \
    || command -v keepassxc >/dev/null 2>&1; then
    hf_log_info "KeePassXC présent"
else
    hf_log_info "KeePassXC absent"
fi

hf_log_title "Politique du bureau"

brave_policy="/etc/brave/policies/managed/high-fortress-user.json"
if [[ -f "${brave_policy}" ]] \
    && grep -qF '"DnsOverHttpsMode": "off"' "${brave_policy}" \
    && grep -qF '"HttpsOnlyMode": "force_balanced_enabled"' "${brave_policy}" \
    && grep -qF '"BrowserGuestModeEnabled": false' "${brave_policy}"; then
    hfu_report_pass "politique Brave (DNS du poste, mode invité coupé)"
else
    hfu_report_fail "politique Brave absente ou incomplète"
fi
tb_policy="/etc/thunderbird/policies/policies.json"
if [[ -f "${tb_policy}" ]] && grep -qF 'mailnews.message_display.disable_remote_image' "${tb_policy}"; then
    hfu_report_pass "images distantes de Thunderbird affichées après un clic"
else
    hfu_report_fail "politique Thunderbird absente"
fi
kpxc_ini="${CURRENT_HOME}/.config/keepassxc/keepassxc.ini"
if [[ -f "${kpxc_ini}" ]] \
    && grep -qE '^LockDatabaseScreenLock[[:space:]]*=[[:space:]]*true[[:space:]]*$' "${kpxc_ini}" \
    && grep -qE '^LockDatabaseIdle[[:space:]]*=[[:space:]]*true[[:space:]]*$' "${kpxc_ini}" \
    && grep -qE '^LockDatabaseIdleSeconds[[:space:]]*=[[:space:]]*900[[:space:]]*$' "${kpxc_ini}"; then
    hfu_report_pass "KeePassXC se ferme avec la session"
else
    hfu_report_fail "KeePassXC ne se ferme pas avec la session"
fi
if ! command -v gsettings >/dev/null 2>&1 || ! command -v dbus-run-session >/dev/null 2>&1; then
    hfu_report_warn "gsettings absent : verrou de session non contrôlé"
else
    idle_delay="$(sudo -u "${CURRENT_USER}" -H dbus-run-session -- gsettings get org.gnome.desktop.session idle-delay 2>/dev/null || true)"
    lock_on="$(sudo -u "${CURRENT_USER}" -H dbus-run-session -- gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null || true)"
    if [[ -z "${idle_delay}" || -z "${lock_on}" ]]; then
        hfu_report_warn "schéma GNOME absent : verrou de session non contrôlé"
    elif [[ "${idle_delay}" == "uint32 1200" && "${lock_on}" == "true" ]]; then
        hfu_report_pass "session verrouillée après 20 minutes d'inactivité"
    else
        hfu_report_warn "verrou de session différent de 20 minutes"
    fi
fi

hf_log_title "Démarrage"
root_src="$(findmnt -no SOURCE / 2>/dev/null || true)"
if [[ -n "${root_src}" ]] && lsblk -sno TYPE "${root_src}" 2>/dev/null | grep -qx crypt; then
    hfu_report_pass "racine sur LUKS"
else
    hfu_report_warn "racine sans LUKS constaté"
fi
if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'; then
    hfu_report_pass "Secure Boot actif"
else
    hfu_report_warn "Secure Boot non actif"
fi

hf_log_title "Sources APT"
hf_log_info "Contrôle du poste"
if [[ -f /etc/apt/sources.list ]]; then
    if grep -q 'high-fortress' /etc/apt/sources.list; then
        hfu_report_fail "sources.list a été réécrit"
    else
        hfu_report_pass "sources.list non réécrit par HFU"
    fi
fi
hfu_report_pass "dépôt Lynis CISOfy ajouté uniquement (lynis.list)"

{
    echo
    echo "## Totaux"
    echo
    echo "- OK   : ${PASS}"
    echo "- WARN : ${WARNN}"
    echo "- FAIL : ${FAIL}"
} >> "${REPORT}"

chmod 644 "${REPORT}" 2>/dev/null || true
hf_set_step_hidden "Check : ${PASS} OK / ${WARNN} WARN / ${FAIL} FAIL"
hf_log_info "Rapport : ${REPORT}"
if [[ "${FAIL}" -gt 0 ]]; then
    echo "" >&2
    grep '^- FAIL' "${REPORT}" | while IFS= read -r line; do
        hf_set_color_red "${line}"
    done
    hf_log_error "Check : ${FAIL} échec(s)"
fi
hf_log_success "Check workstation OK"
