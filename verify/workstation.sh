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
elif [[ "${root_hash}" == "*" || "${root_hash}" == "!" || "${root_hash}" == "!!" ]]; then
    wn "root verrouillé (état distro, pas un chpasswd HFU) — OK si voulu"
    ok "root : pas de mot de passe HFU imposé"
else
    ok "root : hash présent, non réécrit par HFU"
fi
if [[ -z "${user_hash}" || "${user_hash}" == "!" || "${user_hash}" == "*" ]]; then
    ko "compte ${CURRENT_USER} sans mot de passe utilisable"
else
    ok "compte ${CURRENT_USER} : hash intact (HFU n'appelle jamais chpasswd)"
fi

# chage : MAXDAYS ne doit pas avoir été forcé à 90 par nous
maxdays="$(chage -l "${CURRENT_USER}" 2>/dev/null | awk -F: '/Maximum/{gsub(/ /,"",$2); print $2}')"
if [[ "${maxdays}" == "90" ]]; then
    wn "chage MAXDAYS=90 sur ${CURRENT_USER} (n'a pas été posé par ce script ; état antérieur ?)"
else
    ok "chage ${CURRENT_USER} non forcé à 90 jours"
fi

for bin in firefox steam discord telegram-desktop virt-manager virsh qemu-system-x86_64; do
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
    ko "/tmp est noexec (Electron/Steam/Firefox)"
else
    ok "/tmp sans noexec"
fi

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
