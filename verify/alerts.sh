#!/usr/bin/env bash
# =============================================================================
# File       : verify/alerts.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat << 'EOF'
Usage : sudo bash verify/alerts.sh [--no-send]

Contrôle la passe de démarrage qui envoie les alertes, la passe horaire, la passe différée,
ClamAV à l'accès, et le chemin du courrier. Sans --no-send, un seul message d'essai part
quand les alertes sont activées. Le sujet se termine par « Contrôle ».
EOF
    exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lancez ce script avec sudo : sudo bash verify/alerts.sh\n' >&2
    exit 1
fi

send=1
if [[ "${1:-}" == "--no-send" ]]; then
    send=0
elif [[ -n "${1:-}" ]]; then
    printf 'Option inconnue : %s\n' "$1" >&2
    exit 2
fi

G_INSTALL_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export G_INSTALL_DIRECTORY
# shellcheck disable=SC1091
source "${G_INSTALL_DIRECTORY}/config/global.conf"

BASE="${G_CONFIG_BASE_DIRECTORY:-/opt/liltress-workstation}"
BIN="${BASE}/cron/bin"
LOG_DIR="${BASE}/cron/security_logs"
MAIL_CONF="${BASE}/cron/mail.conf"

if [[ -f "${MAIL_CONF}" ]]; then
    # shellcheck disable=SC1090
    source "${MAIL_CONF}"
fi
set -u

FAIL=0
WARN=0
REASONS=()

w_report_section() {
    printf '\n===== %s =====\n' "$1"
}

w_record_fail() {
    FAIL=$((FAIL + 1))
    REASONS+=("ECHEC   $*")
}

w_record_warn() {
    WARN=$((WARN + 1))
    REASONS+=("A_VOIR  $*")
}

w_record_pass() {
    printf 'OK      %s\n' "$*"
}

w_check_unit_word() {
    local unit="$1"
    local active
    active="$(systemctl is-active "${unit}" 2>/dev/null || true)"
    case "${active}" in
        active) printf 'OK' ;;
        inactive|failed|activating|deactivating) printf 'INACTIF' ;;
        *) printf 'ABSENT' ;;
    esac
}

printf 'Liltress Workstation — contrôles qui envoient une alerte\n'
printf 'date : %s\n' "$(date -Iseconds)"
printf 'hôte : %s\n' "$(hostname -s 2>/dev/null || hostname)"
printf 'base : %s\n' "${BASE}"
if [[ "${G_MAIL_ALERTS:-0}" == "1" ]]; then
    printf 'alertes : activées\n'
else
    printf 'alertes : coupées\n'
fi

w_report_section "PASSE AU DEMARRAGE"
timer_word="$(w_check_unit_word w-boot-chain.timer)"
printf '%-36s %s\n' "w-boot-chain.timer" "${timer_word}"
[[ "${timer_word}" == "OK" ]] || w_record_fail "timer de la chaîne de démarrage ${timer_word}"
idle_word="$(w_check_unit_word w-idle-scan.timer)"
printf '%-36s %s\n' "w-idle-scan.timer" "${idle_word}"
[[ "${idle_word}" == "OK" ]] || w_record_fail "timer de passe différée ${idle_word}"
periodic_word="$(w_check_unit_word w-periodic-scan.timer)"
printf '%-36s %s\n' "w-periodic-scan.timer" "${periodic_word}"
[[ "${periodic_word}" == "OK" ]] || w_record_fail "timer d'analyse ClamAV périodique ${periodic_word}"
hourly_word="$(w_check_unit_word w-hourly-scan.timer)"
printf '%-36s %s\n' "w-hourly-scan.timer" "${hourly_word}"
[[ "${hourly_word}" == "OK" ]] || w_record_fail "timer de passe horaire ${hourly_word}"
if [[ -x "${BIN}/boot-scan.sh" ]] \
    && grep -q 'integrity.sh' "${BIN}/boot-scan.sh" \
    && grep -q 'behavior.sh' "${BIN}/boot-scan.sh" \
    && grep -q 'egress-watch.sh' "${BIN}/boot-scan.sh"; then
    w_record_pass "boot-scan.sh exécutable, avec intégrité, audit et journal sortant"
else
    w_record_fail "boot-scan.sh absent ou incomplet dans ${BIN}"
fi
if [[ -x "${BIN}/idle-scan.sh" ]]; then
    w_record_pass "idle-scan.sh exécutable"
else
    w_record_fail "idle-scan.sh absent de ${BIN}"
fi
skip_list="${BASE}/src/config/clamav/scan-skip.paths"
[[ -f "${skip_list}" ]] || skip_list="${BASE}/cron/scan-skip.paths"
if [[ -x "${BASE}/bin/scan-skip.sh" && -f "${skip_list}" ]]; then
    w_record_pass "commande scan-skip.sh et liste des chemins"
else
    w_record_fail "scan-skip.sh ou scan-skip.paths absent"
fi
printf '%-16s %-12s %s\n' "Module" "Script" "Lancé par"
for pair in "Aide aide.sh" "Rkhunter rkhunter.sh" "Chkrootkit chkrootkit.sh" "Clamav clamav.sh" "Debsums debsums.sh"; do
    label="${pair%% *}"
    script="${pair##* }"
    word="ABSENT"
    if [[ -x "${BIN}/${script}" ]]; then
        word="OK"
    elif [[ -f "${BIN}/${script}" ]]; then
        word="NON_EXEC"
    fi
    printf '%-16s %-12s %s\n' "${label}" "${word}" "démarrage"
    [[ "${word}" == "OK" ]] || w_record_fail "${label} : ${BIN}/${script} inutilisable"
done

if [[ -x "${BIN}/clamav-event.sh" ]] && grep -q 'clamav-event.sh' /etc/clamav/clamd.conf 2>/dev/null; then
    w_record_pass "ClamAV à l'accès : VirusEvent pointe vers clamav-event.sh"
else
    w_record_fail "ClamAV à l'accès : VirusEvent ou clamav-event.sh absent"
fi
if [[ -x "${BIN}/clamav-response.sh" ]]; then
    w_record_pass "réponse ClamAV exécutable"
else
    w_record_fail "clamav-response.sh absent de ${BIN}"
fi
if grep -q '^OnAccessIncludePath /tmp$' /etc/clamav/clamd.conf 2>/dev/null \
    && grep -q '^OnAccessIncludePath /var/tmp$' /etc/clamav/clamd.conf 2>/dev/null \
    && ! grep -q '^OnAccessIncludePath /$' /etc/clamav/clamd.conf 2>/dev/null \
    && ! grep -q '^OnAccessIncludePath /home$' /etc/clamav/clamd.conf 2>/dev/null; then
    w_record_pass "surveillance continue sur /tmp et /var/tmp, sans / ni /home"
else
    w_record_fail "surveillance continue incomplète"
fi
if grep -q '/var/lib/clamav/quarantine' /etc/clamav/clamd.conf 2>/dev/null \
    && grep -q '/var/lib/clamav/tmp' /etc/clamav/clamd.conf 2>/dev/null; then
    w_record_pass "quarantaine et temporaire ClamAV exclus"
else
    w_record_fail "quarantaine ou temporaire ClamAV non exclus"
fi

w_report_section "SERVICES"
clam_unit="clamav-clamonacc.service"
if [[ "$(w_check_unit_word clamonacc.service)" == "OK" ]]; then
    clam_unit="clamonacc.service"
fi
for unit in clamav-daemon.service clamav-freshclam.service "${clam_unit}" fail2ban.service auditd.service crowdsec.service crowdsec-firewall-bouncer.service; do
    word="$(w_check_unit_word "${unit}")"
    printf '%-36s %s\n' "${unit}" "${word}"
    [[ "${word}" == "OK" ]] || w_record_fail "service ${unit} ${word}"
done
if [[ "${G_MAIL_ALERTS:-0}" == "1" ]]; then
    word="$(w_check_unit_word postfix.service)"
    printf '%-36s %s\n' "postfix.service" "${word}"
    [[ "${word}" == "OK" ]] || w_record_fail "postfix ${word}"
else
    w_record_pass "postfix non exigé : alertes coupées"
fi
printf 'Fail2Ban, Auditd et CrowdSec n’ont pas de courrier propre. Le courrier vient de la passe et de ClamAV.\n'

w_report_section "DERNIER PASSAGE"
if systemctl show w-boot-scan.service -p ExecMainExitTimestamp --value --no-pager 2>/dev/null | grep -q .; then
    printf 'dernier démarrage de la passe : %s\n' "$(systemctl show w-boot-scan.service -p ExecMainExitTimestamp --value --no-pager 2>/dev/null)"
    printf 'résultat systemd               : %s\n' "$(systemctl show w-boot-scan.service -p Result --value --no-pager 2>/dev/null)"
else
    w_record_warn "la passe de démarrage n'a pas encore de résultat systemd"
fi
printf '%-16s %-12s %s\n' "Module" "Journal" "Modifié"
for name in aide integrity rkhunter behavior chkrootkit clamav debsums egress; do
    file="$(find "${LOG_DIR}" -name "${name}-*.log" -type f 2>/dev/null | sort | tail -1 || true)"
    if [[ -n "${file}" ]]; then
        when="$(date -d "@$(stat -c %Y "${file}")" '+%Y-%m-%d %H:%M' 2>/dev/null || stat -c %y "${file}")"
        printf '%-16s %-12s %s\n' "${name}" "présent" "${when}"
    else
        printf '%-16s %-12s %s\n' "${name}" "absent" "pas encore de passage"
    fi
done

w_report_section "CHEMIN DU COURRIER"
if [[ -x "${BIN}/send.sh" ]]; then
    w_record_pass "send.sh exécutable"
else
    w_record_fail "send.sh absent de ${BIN}"
fi
if [[ -f "${BIN}/mail.html" || -f "${BIN}/template/mail.html" ]]; then
    w_record_pass "modèle HTML présent"
else
    w_record_fail "modèle HTML absent de ${BIN}"
fi
if command -v mail >/dev/null 2>&1; then
    w_record_pass "commande mail présente"
else
    w_record_fail "commande mail absente"
fi
if [[ "${G_MAIL_ALERTS:-0}" == "1" && -z "${G_WATCHDOG_MAIL:-}" ]]; then
    w_record_fail "alertes activées sans destinataire"
elif [[ "${G_MAIL_ALERTS:-0}" == "1" ]]; then
    w_record_pass "destinataire défini"
else
    w_record_pass "aucun destinataire exigé : alertes coupées"
fi

if [[ "${send}" -eq 0 ]]; then
    w_record_pass "essai non lancé (--no-send)"
elif [[ "${G_MAIL_ALERTS:-0}" != "1" ]]; then
    w_record_pass "essai non lancé : alertes coupées"
elif [[ "${FAIL}" -ne 0 ]]; then
    w_record_warn "essai non lancé : le chemin du courrier a déjà un échec"
else
    stamp="$(date +%Y%m%d-%H%M%S)"
    export DATE="$(date '+%Y-%m-%d %H:%M:%S')"
    export MODULE_NAME="Contrôle"
    export TITLE="Contrôle des alertes"
    export CONTENT="Contrôle Liltress Workstation. Ce message confirme que les alertes partent. Jeton ${stamp}."
    export NOTE=""
    export NOTE_CMD=""
    export G_PROJECT_NAME="${G_PROJECT_NAME:-Liltress Workstation}"
    export G_MAIL_TEMPLATE="${G_MAIL_TEMPLATE:-mail.html}"
    started="$(date +%s)"
    probe="$(bash "${BIN}/send.sh" 2>&1 || true)"
    if printf '%s\n' "${probe}" | grep -q 'Mail non envoyé'; then
        w_record_fail "essai refusé par send.sh"
        printf '%s\n' "${probe}" | sed -n '1,8p'
    else
        ack=""
        for _ in 1 2 3 4 5; do
            sleep 4
            ack="$(journalctl -u postfix --since "@${started}" --no-pager 2>/dev/null | grep -E 'status=(sent|deferred|bounced)' | tail -1 || true)"
            [[ -n "${ack}" ]] && break
        done
        if [[ "${ack}" == *status=sent* ]]; then
            w_record_pass "essai parti (status=sent, sujet se terminant par Contrôle)"
        elif [[ "${ack}" == *status=deferred* || "${ack}" == *status=bounced* ]]; then
            w_record_fail "essai non remis (SMTP deferred ou bounced)"
        elif [[ -z "$(mailq 2>/dev/null | sed -n '1p' | grep -v 'Mail queue is empty' || true)" ]]; then
            w_record_warn "essai accepté localement, accusé SMTP pas encore dans le journal"
        else
            w_record_fail "essai encore en file d'attente"
        fi
    fi
fi

if [[ "${#REASONS[@]}" -gt 0 ]]; then
    w_report_section "A CORRIGER"
    printf '%s\n' "${REASONS[@]}"
fi

w_report_section "RESULTAT"
if [[ "${FAIL}" -eq 0 && "${WARN}" -eq 0 ]]; then
    printf 'Résultat : OK\n'
    exit 0
fi
if [[ "${FAIL}" -eq 0 ]]; then
    printf 'Résultat : OK, %s point(s) à confirmer\n' "${WARN}"
    exit 0
fi
printf 'Résultat : %s échec(s), %s point(s) à confirmer\n' "${FAIL}" "${WARN}"
exit 1
