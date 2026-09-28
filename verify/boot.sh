#!/usr/bin/env bash
# =============================================================================
# Fichier    : verify/boot.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Relit, après un redémarrage, l'état des services de sécurité et les
#   derniers journaux. La sortie est faite pour être copiée telle quelle.
#   Aucun mot de passe ni jeton n'est affiché.
#
# Lancer :
#   sudo bash verify/boot.sh
# =============================================================================

set +e

if [[ "${EUID}" -ne 0 ]]; then
    echo "Lancez ce script avec sudo : sudo bash verify/boot.sh" >&2
    exit 1
fi

section() {
    printf '\n===== %s =====\n' "$1"
}

echo "High-Fortress User — état après démarrage"
echo "date : $(date -Iseconds)"
echo "hôte : $(hostname)"
echo "démarrage : $(uptime -s 2>/dev/null || who -b)"

section "ETAT DES SERVICES"
services=(
    ssh.service
    clamav-daemon.service
    clamav-freshclam.service
    clamav-clamonacc.service
    crowdsec.service
    crowdsec-firewall-bouncer.service
    fail2ban.service
    auditd.service
    apparmor.service
    postfix.service
    unattended-upgrades.service
    hfu-boot-scan.timer
)
for unit in "${services[@]}"; do
    enabled="$(systemctl is-enabled "${unit}" 2>/dev/null || echo absent)"
    active="$(systemctl is-active "${unit}" 2>/dev/null || echo absent)"
    mark="OK"
    if [[ "${active}" != "active" ]]; then
        mark="A_VOIR"
    fi
    printf '%-8s %-36s enabled=%-10s active=%s\n' "${mark}" "${unit}" "${enabled}" "${active}"
done

section "SSH EFFECTIF"
sshd -T 2>/dev/null | awk '/^permitrootlogin |^passwordauthentication /'

section "CLAMONACC"
journalctl -u clamav-clamonacc.service -b --no-pager -n 40
echo
echo "--- chemins surveillés ---"
grep -E '^(OnAccess|TemporaryDirectory|VirusEvent)' /etc/clamav/clamd.conf 2>/dev/null

section "PASSE AU DEMARRAGE"
systemctl status hfu-boot-scan.timer --no-pager -l
echo
echo "--- dernier passage ---"
journalctl -u hfu-boot-scan.service -b --no-pager -n 40

section "CROWDSEC"
cscli version 2>/dev/null
cscli collections list 2>/dev/null
cscli metrics 2>/dev/null | head -50

section "JOURNAUX DE CONTROLE"
log_dir="/opt/high-fortress-user/cron/security_logs"
alert_dir="/opt/high-fortress-user/cron/alerts"
ls -lt "${log_dir}" 2>/dev/null | head -15
echo
ls -lt "${alert_dir}" 2>/dev/null | head -10
echo
echo "--- extrait du dernier journal AIDE (résumé) ---"
latest_aide="$(ls -t "${log_dir}"/aide-*.log 2>/dev/null | head -1)"
if [[ -n "${latest_aide}" ]]; then
    grep -E -i 'summary:|total number|added entries|removed entries|changed entries|aide found|erreur' "${latest_aide}" | head -30
else
    echo "aucun journal AIDE"
fi
echo
echo "--- dernier journal chkrootkit ---"
latest_chk="$(ls -t "${log_dir}"/chkrootkit-*.log 2>/dev/null | head -1)"
if [[ -n "${latest_chk}" ]]; then
    sed -n '1,40p' "${latest_chk}"
else
    echo "aucun journal chkrootkit"
fi

section "FIN"
echo "Copiez toute cette sortie pour l'analyse."
exit 0
