#!/usr/bin/env bash
# =============================================================================
# File       : verify/alerts.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat << 'EOF'
Usage : sudo bash verify/alerts.sh [--no-send]

Contrôle la passe de démarrage qui envoie les alertes, ClamAV à l'accès,
et le chemin du courrier. Sans --no-send, un seul message d'essai part
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

DIR_INSTALL_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export DIR_INSTALL_PATH
# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/config/global.conf"

BASE="${CONFIG_BASE_DIR:-/opt/high-fortress-user}"
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

section() {
    printf '\n===== %s =====\n' "$1"
}

note_fail() {
    FAIL=$((FAIL + 1))
    REASONS+=("ECHEC   $*")
}

note_warn() {
    WARN=$((WARN + 1))
    REASONS+=("A_VOIR  $*")
}

note_ok() {
    printf 'OK      %s\n' "$*"
}

unit_word() {
    local unit="$1"
    local active
    active="$(systemctl is-active "${unit}" 2>/dev/null || true)"
    case "${active}" in
        active) printf 'OK' ;;
        inactive|failed|activating|deactivating) printf 'INACTIF' ;;
        *) printf 'ABSENT' ;;
    esac
}

printf 'High-Fortress User — contrôles qui envoient une alerte\n'
printf 'date : %s\n' "$(date -Iseconds)"
printf 'hôte : %s\n' "$(hostname -s 2>/dev/null || hostname)"
printf 'base : %s\n' "${BASE}"
if [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then
    printf 'alertes : activées\n'
else
    printf 'alertes : coupées\n'
fi

section "PASSE AU DEMARRAGE"
timer_word="$(unit_word hfu-boot-scan.timer)"
printf '%-36s %s\n' "hfu-boot-scan.timer" "${timer_word}"
[[ "${timer_word}" == "OK" ]] || note_fail "timer de passe au démarrage ${timer_word}"
if [[ -x "${BIN}/boot-scan.sh" ]]; then
    note_ok "boot-scan.sh exécutable"
else
    note_fail "boot-scan.sh absent de ${BIN}"
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
    [[ "${word}" == "OK" ]] || note_fail "${label} : ${BIN}/${script} inutilisable"
done

if [[ -x "${BIN}/clamav-event.sh" ]] && grep -q 'clamav-event.sh' /etc/clamav/clamd.conf 2>/dev/null; then
    note_ok "ClamAV à l'accès : VirusEvent pointe vers clamav-event.sh"
else
    note_fail "ClamAV à l'accès : VirusEvent ou clamav-event.sh absent"
fi

section "SERVICES"
clam_unit="clamav-clamonacc.service"
if [[ "$(unit_word clamonacc.service)" == "OK" ]]; then
    clam_unit="clamonacc.service"
fi
for unit in clamav-daemon.service clamav-freshclam.service "${clam_unit}" fail2ban.service auditd.service crowdsec.service crowdsec-firewall-bouncer.service; do
    word="$(unit_word "${unit}")"
    printf '%-36s %s\n' "${unit}" "${word}"
    [[ "${word}" == "OK" ]] || note_fail "service ${unit} ${word}"
done
if [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then
    word="$(unit_word postfix.service)"
    printf '%-36s %s\n' "postfix.service" "${word}"
    [[ "${word}" == "OK" ]] || note_fail "postfix ${word}"
else
    note_ok "postfix non exigé : alertes coupées"
fi
printf 'Fail2Ban, Auditd et CrowdSec n’ont pas de courrier propre. Le courrier vient de la passe et de ClamAV.\n'

section "DERNIER PASSAGE"
if systemctl show hfu-boot-scan.service -p ExecMainExitTimestamp --value --no-pager 2>/dev/null | grep -q .; then
    printf 'dernier démarrage de la passe : %s\n' "$(systemctl show hfu-boot-scan.service -p ExecMainExitTimestamp --value --no-pager 2>/dev/null)"
    printf 'résultat systemd               : %s\n' "$(systemctl show hfu-boot-scan.service -p Result --value --no-pager 2>/dev/null)"
else
    note_warn "la passe de démarrage n'a pas encore de résultat systemd"
fi
printf '%-16s %-12s %s\n' "Module" "Journal" "Modifié"
for name in aide rkhunter chkrootkit clamav debsums; do
    file="$(find "${LOG_DIR}" -name "${name}-*.log" -type f 2>/dev/null | sort | tail -1 || true)"
    if [[ -n "${file}" ]]; then
        when="$(date -d "@$(stat -c %Y "${file}")" '+%Y-%m-%d %H:%M' 2>/dev/null || stat -c %y "${file}")"
        printf '%-16s %-12s %s\n' "${name}" "présent" "${when}"
    else
        printf '%-16s %-12s %s\n' "${name}" "absent" "pas encore de passage"
    fi
done

section "CHEMIN DU COURRIER"
if [[ -x "${BIN}/send.sh" ]]; then
    note_ok "send.sh exécutable"
else
    note_fail "send.sh absent de ${BIN}"
fi
if [[ -f "${BIN}/mail.html" || -f "${BIN}/template/mail.html" ]]; then
    note_ok "modèle HTML présent"
else
    note_fail "modèle HTML absent de ${BIN}"
fi
if command -v mail >/dev/null 2>&1; then
    note_ok "commande mail présente"
else
    note_fail "commande mail absente"
fi
if [[ "${HF_MAIL_ALERTS:-0}" == "1" && -z "${WATCHDOG_MAIL:-}" ]]; then
    note_fail "alertes activées sans destinataire"
elif [[ "${HF_MAIL_ALERTS:-0}" == "1" ]]; then
    note_ok "destinataire défini"
else
    note_ok "aucun destinataire exigé : alertes coupées"
fi

if [[ "${send}" -eq 0 ]]; then
    note_ok "essai non lancé (--no-send)"
elif [[ "${HF_MAIL_ALERTS:-0}" != "1" ]]; then
    note_ok "essai non lancé : alertes coupées"
elif [[ "${FAIL}" -ne 0 ]]; then
    note_warn "essai non lancé : le chemin du courrier a déjà un échec"
else
    stamp="$(date +%Y%m%d-%H%M%S)"
    export DATE="$(date '+%Y-%m-%d %H:%M:%S')"
    export MODULE_NAME="Contrôle"
    export TITLE="Contrôle des alertes"
    export CONTENT="Contrôle High-Fortress User. Ce message confirme que les alertes partent. Jeton ${stamp}."
    export NOTE=""
    export NOTE_CMD=""
    export PROJECT_NAME="${PROJECT_NAME:-High-Fortress User}"
    export MAIL_TEMPLATE="${MAIL_TEMPLATE:-mail.html}"
    started="$(date +%s)"
    probe="$(bash "${BIN}/send.sh" 2>&1 || true)"
    if printf '%s\n' "${probe}" | grep -q 'Mail non envoyé'; then
        note_fail "essai refusé par send.sh"
        printf '%s\n' "${probe}" | sed -n '1,8p'
    else
        ack=""
        for _ in 1 2 3 4 5; do
            sleep 4
            ack="$(journalctl -u postfix --since "@${started}" --no-pager 2>/dev/null | grep -E 'status=(sent|deferred|bounced)' | tail -1 || true)"
            [[ -n "${ack}" ]] && break
        done
        if [[ "${ack}" == *status=sent* ]]; then
            note_ok "essai parti (status=sent, sujet se terminant par Contrôle)"
        elif [[ "${ack}" == *status=deferred* || "${ack}" == *status=bounced* ]]; then
            note_fail "essai non remis (SMTP deferred ou bounced)"
        elif [[ -z "$(mailq 2>/dev/null | sed -n '1p' | grep -v 'Mail queue is empty' || true)" ]]; then
            note_warn "essai accepté localement, accusé SMTP pas encore dans le journal"
        else
            note_fail "essai encore en file d'attente"
        fi
    fi
fi

if [[ "${#REASONS[@]}" -gt 0 ]]; then
    section "A CORRIGER"
    printf '%s\n' "${REASONS[@]}"
fi

section "RESULTAT"
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
