#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/02_file_graph.sh
# Updated at : 2026-10-16
# Creator    : palarchsys
# =============================================================================

hft_section "étapes de run.sh"
while IFS= read -r step; do
    [[ -z "${step}" ]] && continue
    if [[ -f "${HFT_ROOT}/${step}" ]]; then
        hft_pass "graph:${step}" "présent"
    else
        hft_fail "graph:${step}" "introuvable"
    fi
done < <(grep -oE '"(system|service|verify)/[^"]+\.sh"' "${HFT_ROOT}/scripts/run.sh" | tr -d '"' | sort -u)

hft_section "désinstallations avant system/install"
snap_line=$(grep -n 'system/snapd.sh' "${HFT_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
purge_line=$(grep -n 'STEP_SYSTEM_PURGE\[@\]' "${HFT_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
inst_line=$(grep -n 'STEP_SYSTEM_INSTALL\[@\]' "${HFT_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
if [[ -n "${snap_line}" && -n "${purge_line}" && -n "${inst_line}" \
      && "${snap_line}" -lt "${purge_line}" && "${purge_line}" -lt "${inst_line}" ]] \
   && grep -q 'systemctl mask systemd-coredump.socket' "${HFT_ROOT}/system/purge.sh" \
   && ! grep -q 'systemctl mask systemd-coredump.socket' "${HFT_ROOT}/system/configure.sh" \
   && ! grep -qE 'purge -y cups|disable --now cups|mask apport' "${HFT_ROOT}/system/purge.sh" \
   && awk '
        /upgrade -y --with-new-pkgs/ { up = NR }
        /HF_REAPPLY_LOCKS=1/ { if (up && !re) re = NR }
        END { exit !(up && re && re > up) }
      ' "${HFT_ROOT}/scripts/run.sh"; then
    hft_pass "graph.order.purge-first" "snap (L${snap_line}), purge (L${purge_line}), install (L${inst_line})"
else
    hft_fail "graph.order.purge-first" "snap puis purge rc/coredump avant system/install ; CUPS reste"
fi

hft_section "purge rc avant les bases rkhunter et AIDE"
rc_line=$(grep -n 'HF_PURGE_REMOVED_CONFIG_ONLY=1' "${HFT_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
rk_line=$(grep -n 'service/rkhunter/init-db.sh' "${HFT_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
aide_line=$(grep -n 'service/aide/init-db.sh' "${HFT_ROOT}/scripts/run.sh" | head -1 | cut -d: -f1)
if [[ -n "${rc_line}" && -n "${rk_line}" && -n "${aide_line}" \
      && "${rc_line}" -lt "${rk_line}" && "${rk_line}" -lt "${aide_line}" ]] \
   && ! grep -q 'dpkg --purge' "${HFT_ROOT}/system/install.sh" \
   && ! grep -qF 'hf_run_silent rkhunter --propupd' "${HFT_ROOT}/service/rkhunter/configure.sh" \
   && grep -qF 'hf_run_silent rkhunter --propupd' "${HFT_ROOT}/service/rkhunter/init-db.sh"; then
    hft_pass "graph.order.purge-before-db" "purge rc (L${rc_line}) avant rkhunter (L${rk_line}) et AIDE (L${aide_line})"
else
    hft_fail "graph.order.purge-before-db" "la purge rc doit précéder --propupd et aide --init"
fi

hft_section "ordre des contrôles quotidiens"
if awk '
    function remember(name, s) { arr[name] = arr[name] s "\n" }
    function add(s) { step[++n] = s }
    function take_scripts(line,    rest, s) {
        rest = line
        while (match(rest, /"(system|service|verify)\/[^"]+\.sh"/)) {
            s = substr(rest, RSTART + 1, RLENGTH - 2)
            if (inarr) remember(cur, s)
            else add(s)
            rest = substr(rest, RSTART + RLENGTH)
        }
    }
    function pos(name,    i) {
        for (i = 1; i <= n; i++) if (step[i] == name) return i
        return 0
    }
    /^[A-Za-z0-9_]+=\(/ {
        cur = $0
        sub(/=.*/, "", cur)
        inarr = 1
        take_scripts($0)
        if ($0 ~ /\)/) inarr = 0
        next
    }
    inarr {
        take_scripts($0)
        if ($0 ~ /\)/) inarr = 0
        next
    }
    /upgrade -y --with-new-pkgs/ { add("UPGRADE"); next }
    /\$\{STEP_[A-Z0-9_]+\[@\]\}/ {
        if (match($0, /STEP_[A-Z0-9_]+/)) {
            cur = substr($0, RSTART, RLENGTH)
            nlines = split(arr[cur], parts, "\n")
            for (i = 1; i <= nlines; i++) if (parts[i] != "") add(parts[i])
        }
        next
    }
    /hf_run_step/ { take_scripts($0); next }
    END {
        ssh = pos("service/ssh/configure.sh")
        ufw = pos("service/ufw/configure.sh")
        uinst = pos("service/usbguard/install.sh")
        uconf = pos("service/usbguard/configure.sh")
        cinst = pos("service/clamav/install.sh")
        cconf = pos("service/clamav/configure.sh")
        userns = pos("service/apparmor/userns.sh")
        dconf = pos("service/desktop/configure.sh")
        rk = pos("service/rkhunter/init-db.sh")
        aide = pos("service/aide/init-db.sh")
        ver = pos("verify/workstation.sh")
        up = pos("UPGRADE")
        exit !(ssh && ufw && ssh < ufw \
            && uinst && uconf && uinst < uconf \
            && cinst && cconf && cinst < cconf && cconf < userns \
            && userns && up && dconf && uconf \
            && userns < up && up < dconf && dconf < uconf \
            && uconf < rk && rk < aide && aide < ver)
    }
' "${HFT_ROOT}/scripts/run.sh"; then
    hft_pass "graph.order.daily" "SSH avant UFW, bureau après correctifs, verify après AIDE"
else
    hft_fail "graph.order.daily" "USBGuard et les politiques suivent les paquets ; verify suit AIDE"
fi

hft_section "modèle de mail dans template/"
if [[ -f "${HFT_ROOT}/template/mail.html" ]]; then
    hft_pass "graph.template:mail.html" "présent : template/mail.html"
else
    hft_fail "graph.template:mail.html" "fichier introuvable : template/mail.html"
fi
if [[ -e "${HFT_ROOT}/service/cron/watchdogs/mail.html" ]]; then
    hft_fail "graph.template:not-in-watchdogs" "mail.html est encore dans service/cron/watchdogs"
else
    hft_pass "graph.template:not-in-watchdogs" "le modèle n'est pas enfoui dans les watchdogs"
fi

hft_section "debsums et mirrors.dat"
rk="${HFT_ROOT}/service/cron/watchdogs/rkhunter.sh"
check_line="$(grep -n 'record-mirrors.sh" check' "${rk}" | head -1 | cut -d: -f1)"
update_line="$(grep -n 'rkhunter --update' "${rk}" | head -1 | cut -d: -f1)"
save_line="$(grep -n 'record-mirrors.sh" save' "${rk}" | head -1 | cut -d: -f1)"
if [[ -x "${HFT_ROOT}/service/cron/watchdogs/record-mirrors.sh" ]] \
   && [[ -n "${check_line}" && -n "${update_line}" && -n "${save_line}" ]] \
   && [[ "${check_line}" -lt "${update_line}" && "${update_line}" -lt "${save_line}" ]] \
   && grep -q 'rkhunter-mirrors.sha256' "${HFT_ROOT}/service/cron/watchdogs/debsums.sh" \
   && grep -q 'perl-base/unicore' "${HFT_ROOT}/service/cron/watchdogs/debsums.sh" \
   && grep -q 'record-mirrors.sh" save' "${HFT_ROOT}/service/rkhunter/init-db.sh" \
   && [[ ! -e "${HFT_ROOT}/service/cron/watchdogs/debsums.ignore" ]]; then
    hft_pass "graph.debsums.mirrors" "empreinte après --update, le fichier n'est pas ignoré"
else
    hft_fail "graph.debsums.mirrors" "mirrors.dat doit rester contrôlé hors de rkhunter --update"
fi

hft_section "clamav verrous de quarantaine"
evt="${HFT_ROOT}/service/cron/watchdogs/clamav-event.sh"
if grep -q 'clamav-quarantine-lock' "${evt}" \
   && awk '
        /clamav-quarantine-lock/ { lock = NR }
        /hf_log_alert/ { if (lock && !alert) alert = NR }
        END { exit !(lock && alert && alert > lock) }
      ' "${evt}"; then
    hft_pass "graph.clamav.locks" "un verrou de quarantaine sort avant le courrier"
else
    hft_fail "graph.clamav.locks" "les verrous .clamav-quarantine-lock.* ne doivent pas envoyer de courrier"
fi

hft_section "chemins exclus du scan"
skip_lib="${HFT_ROOT}/service/cron/watchdogs/scan-skip-lib.sh"
skip_tpl="${HFT_ROOT}/config/clamav/scan-skip.paths"
skip_apply="${HFT_ROOT}/service/cron/watchdogs/apply-scan-skip.sh"
skip_cmd="${HFT_ROOT}/service/cron/scan-skip.sh"
skip_idle="${HFT_ROOT}/service/cron/watchdogs/idle-scan.sh"
skip_boot="${HFT_ROOT}/service/cron/watchdogs/boot-scan.sh"
skip_clam="${HFT_ROOT}/service/cron/watchdogs/clamav.sh"
if [[ -f "${skip_lib}" && -f "${skip_tpl}" && -f "${skip_apply}" && -f "${skip_cmd}" && -f "${skip_idle}" ]] \
   && grep -q '/var/jeux' "${skip_tpl}" \
   && grep -q '/.steam' "${skip_tpl}" \
   && grep -q '/.local/share/Steam' "${skip_tpl}" \
   && grep -q '__HOME__' "${skip_tpl}" \
   && ! grep -q 'BraveSoftware' "${skip_tpl}" \
   && ! grep -q '.config/discord' "${skip_tpl}" \
   && ! grep -q '.thunderbird' "${skip_tpl}" \
   && ! grep -q 'BraveSoftware' "${skip_lib}" \
   && ! grep -q '.config/discord' "${skip_lib}" \
   && ! grep -q '.thunderbird' "${skip_lib}" \
   && grep -qF "printf '%s\\n' / /home /opt /tmp /etc /usr /var /boot /root" "${skip_lib}" \
   && grep -q '# home=' "${skip_tpl}" \
   && grep -qF '/var/jeux/*' "${skip_lib}" \
   && grep -q 'BEGIN High-Fortress User scan-skip' "${skip_apply}" \
   && grep -q 'OnAccessExcludePath' "${skip_apply}" \
   && grep -q 'systemctl restart clamav-daemon' "${skip_apply}" \
   && grep -q 'clamav-clamonacc.service' "${skip_apply}" \
   && ! grep -q 'systemctl reload' "${skip_apply}" \
   && grep -q 'HFU_SCAN_SKIP_HOME' "${HFT_ROOT}/service/clamav/configure.sh" \
   && grep -q 'HFU_SCAN_SKIP_HOME' "${HFT_ROOT}/service/cron/configure.sh" \
   && awk '
        /apply-scan-skip\.sh/ { apply = NR }
        /aide\.sh/ { if (apply && !aide) aide = NR }
        END { exit !(apply && aide && aide > apply) }
      ' "${skip_boot}" \
   && ! grep -q 'clamdscan' "${skip_clam}" \
   && grep -q 'hf_list_clamav_scan' "${skip_clam}" \
   && grep -q 'hf_report_clamav' "${skip_clam}" \
   && grep -q 'clamscan --infected --no-summary' "${HFT_ROOT}/../core/watchdog.sh" \
   && grep -q 'planté signal' "${HFT_ROOT}/../core/watchdog.sh" \
   && grep -q 'tool="clamscan"' "${HFT_ROOT}/../core/watchdog.sh" \
   && grep -q 'scan-skip.sh list' "${skip_cmd}" \
   && grep -q 'scan-skip.sh add' "${skip_cmd}" \
   && grep -q 'scan-skip.sh del' "${skip_cmd}" \
   && grep -q 'pgrep -x' "${skip_idle}" \
   && grep -q 'hf_list_clamav_scan' "${skip_idle}" \
   && grep -q 'hf_report_clamav' "${skip_idle}" \
   && ! grep -q 'interrompu, aucun virus' "${skip_clam}" \
   && ! grep -q 'interrompu, aucun virus' "${skip_idle}" \
   && grep -q 'hf_get_crash_sentence' "${skip_boot}" \
   && grep -q 'hf_get_crash_sentence' "${HFT_ROOT}/service/cron/watchdogs/aide.sh" \
   && grep -q 'hf_get_crash_sentence' "${HFT_ROOT}/service/cron/watchdogs/rkhunter.sh" \
   && grep -q 'hf_get_crash_sentence' "${HFT_ROOT}/service/cron/watchdogs/chkrootkit.sh" \
   && grep -q 'hf_get_crash_sentence' "${HFT_ROOT}/service/cron/watchdogs/debsums.sh" \
   && grep -q 'hf_log_alert "clamscan : infection(s)' "${skip_clam}" \
   && grep -q 'hf_log_alert "AIDE: changements détectés' "${HFT_ROOT}/service/cron/watchdogs/aide.sh" \
   && grep -q 'hf_log_alert "rkhunter warnings' "${HFT_ROOT}/service/cron/watchdogs/rkhunter.sh" \
   && grep -q 'hf_log_alert "chkrootkit a produit une sortie' "${HFT_ROOT}/service/cron/watchdogs/chkrootkit.sh" \
   && grep -q 'hf_log_alert "debsums : fichiers modifiés' "${HFT_ROOT}/service/cron/watchdogs/debsums.sh" \
   && grep -q 'hf_log_alert "ClamAV :' "${HFT_ROOT}/service/cron/watchdogs/clamav-event.sh" \
   && grep -q 'hf_get_clamav_kind' "${skip_clam}" \
   && grep -q 'hf_get_clamav_kind' "${skip_idle}" \
   && grep -q 'ALLOWDEVFILE=/dev/log' "${HFT_ROOT}/config/rkhunter/rkhunter.conf.local" \
   && grep -qF "'/dev/log'" "${HFT_ROOT}/service/cron/watchdogs/rkhunter.sh" \
   && grep -q 'hfu-idle-scan.timer' "${HFT_ROOT}/service/cron/configure.sh" \
   && grep -q 'High-Fortress User onaccess' "${HFT_ROOT}/config/clamav/onaccess.conf" \
   && ! grep -q 'OnAccessExcludePath' "${HFT_ROOT}/service/clamav/configure.sh"; then
    hft_pass "graph.scan-skip" "fichier de chemins, commande, passe différée, sans Brave ni Discord ni Thunderbird"
else
    hft_fail "graph.scan-skip" "les exclusions passent par scan-skip.paths et ne retirent pas Brave, Discord ni Thunderbird"
fi

hft_section "ordre Unbound et liste chkrootkit"
order_ok=1
if grep -q 'systemd-resolved' "${HFT_ROOT}/config/unbound/unbound.service.conf"; then
    order_ok=0
fi
if grep -q '^After=unbound' "${HFT_ROOT}/config/unbound/resolved.service.conf"; then
    order_ok=0
fi
grep -q '^Wants=unbound.service$' "${HFT_ROOT}/config/unbound/resolved.service.conf" || order_ok=0
grep -q 'chkrootkit/chkrootkit.ignore' "${HFT_ROOT}/service/chkrootkit/install.sh" || order_ok=0
grep -q 'src/config/chkrootkit' "${HFT_ROOT}/service/chkrootkit/install.sh" || order_ok=0
if [[ "${order_ok}" -eq 1 ]]; then
    hft_pass "graph.unbound.order" "Unbound après le réseau, liste chkrootkit installée"
else
    hft_fail "graph.unbound.order" "Unbound ne doit pas précéder systemd-resolved, la liste chkrootkit doit être copiée"
fi

hft_section "plafond CPU"
cpu_rc=0
bash -s -- "${HFT_ROOT}" << 'CPU' || cpu_rc=$?
set -euo pipefail
root="$1"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
printf '%s\n' '#!/bin/sh' 'echo 4' > "${work}/nproc"
chmod 755 "${work}/nproc"
got="$(PATH="${work}:${PATH}" HF_WATCHDOG_CPU_LIMIT=20 bash -c 'source "$1" && hf_get_cpu_quota_percent' _ "${root}/../core/watchdog.sh")"
[[ "${got}" == "80" ]]
grep -qF 'hf_get_cpu_quota_percent' "${root}/service/cron/configure.sh"
grep -qF 'CPUQuota=${cpu_quota}%' "${root}/config/cron/hfu-boot-scan.service"
grep -qF 'CPUQuota=${cpu_quota}%' "${root}/config/cron/hfu-idle-scan.service"
grep -qF 'CPUQuota=${cpu_quota}%' "${root}/config/cron/hfu-reboot-notice.service"
! grep -qF 'CPUQuota=${HF_WATCHDOG_CPU_LIMIT}%' \
    "${root}/service/cron/configure.sh" \
    "${root}/config/cron/hfu-boot-scan.service" \
    "${root}/config/cron/hfu-idle-scan.service" \
    "${root}/config/cron/hfu-reboot-notice.service" \
    "${root}/config/cron/hfu-boot-chain.service"
CPU
if [[ "${cpu_rc}" -eq 0 ]]; then
    hft_pass "graph.cpu.quota" "20 % de la machine, CPUQuota multiplié par le nombre de CPU"
else
    hft_fail "graph.cpu.quota" "CPUQuota doit valoir HF_WATCHDOG_CPU_LIMIT fois le nombre de CPU"
fi

hft_section "chaîne de démarrage"
chain_rc=0
bash -s -- "${HFT_ROOT}" << 'CHAIN' || chain_rc=$?
set -euo pipefail
root="$1"
conf="${root}/service/cron/configure.sh"
chain="${root}/config/cron/hfu-boot-chain.service"
boot_timer="${root}/config/cron/hfu-boot-chain.timer"
idle_timer="${root}/config/cron/hfu-idle-scan.timer"
reboot_timer="${root}/config/cron/hfu-reboot-notice.timer"
units="${root}/config/cron"
grep -qF 'ExecStart=-${systemctl_bin} start --wait hfu-boot-scan.service' "${chain}"
grep -qF 'ExecStart=-${systemctl_bin} start --wait hfu-idle-scan.service' "${chain}"
grep -qF 'ExecStart=-${systemctl_bin} start --wait hfu-reboot-notice.service' "${chain}"
timers="${root}/config/cron/timers.conf"
grep -q 'OnBootSec=${HFU_BOOT_ON_BOOT_SEC}' "${boot_timer}"
grep -q 'HFU_BOOT_ON_BOOT_SEC=0' "${timers}"
grep -q 'OnUnitActiveSec=${HFU_IDLE_EVERY}' "${idle_timer}"
grep -q 'HFU_IDLE_EVERY=1h' "${timers}"
grep -q 'OnUnitActiveSec=${HFU_REBOOT_EVERY}' "${reboot_timer}"
grep -q 'HFU_REBOOT_EVERY=6h' "${timers}"
grep -q 'Persistent=${HFU_TIMER_PERSISTENT}' "${boot_timer}"
grep -q 'Persistent=${HFU_TIMER_PERSISTENT}' "${idle_timer}"
grep -q 'Persistent=${HFU_TIMER_PERSISTENT}' "${reboot_timer}"
grep -q 'HFU_TIMER_PERSISTENT=false' "${timers}"
grep -q 'hfu-boot-chain.timer' "${conf}"
grep -q 'boot-check.sh' "${conf}"
grep -q 'systemctl disable --now hfu-boot-scan.timer' "${conf}"
! grep -q 'OnBootSec=2min' "${conf}" "${timers}" "${units}"/*.service "${units}"/*.timer
! grep -q 'OnBootSec=15min' "${conf}" "${timers}" "${units}"/*.service "${units}"/*.timer
! grep -q 'OnBootSec=20min' "${conf}" "${timers}" "${units}"/*.service "${units}"/*.timer
! grep -q 'Persistent=true' "${conf}" "${timers}" "${units}"/*.service "${units}"/*.timer
grep -q 'hfu-boot-chain.timer' "${root}/verify/alerts.sh"
grep -q 'hfu-boot-chain.timer' "${root}/verify/workstation.sh"
grep -q 'boot-check.sh' "${root}/verify/boot.sh"
test -f "${root}/service/cron/boot-check.sh"
grep -q '39f53479d3a045ac8e11786248231fbf' "${root}/service/cron/boot-check.sh"
grep -q 'be02cf6855d2428ba40df7e9d022f03d' "${root}/service/cron/boot-check.sh"
grep -q 'd9b373ed55a64feb8242e02dbe79a49c' "${root}/service/cron/boot-check.sh"
grep -q 'src/config/global.conf' "${root}/service/cron/boot-check.sh"
CHAIN
if [[ "${chain_rc}" -eq 0 ]]; then
    hft_pass "graph.boot.chain" "chaîne sans délai fixe, contrôle manuel installé"
else
    hft_fail "graph.boot.chain" "la chaîne doit enchaîner les trois passes, et le contrôle doit lire le journal si l'heure de début a disparu"
fi

hft_section "alerte de plantage et incident"
crash_rc=0
bash -s -- "${HFT_ROOT}" << 'CRASH' || crash_rc=$?
set -euo pipefail
root="$1"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
mkdir -p "${work}/cron/bin" "${work}/bin"
cat > "${work}/cron/mail.conf" << EOF
HF_MAIL_ALERTS="1"
HF_WATCHDOG_MAIL="alerts@example.com"
HF_PROJECT_NAME="High-Fortress User"
EOF
cat > "${work}/cron/bin/send.sh" << 'EOF'
#!/usr/bin/env bash
printf '%s\n----\n' "${CONTENT}" >> "${HFU_SENT}"
EOF
chmod 755 "${work}/cron/bin/send.sh"
cat > "${work}/bin/clamscan" << 'EOF'
#!/usr/bin/env bash
for f in "$@"; do
    [[ "${f}" == "--" ]] && continue
    printf 'scan %s\n' "${f}" >> "${HFU_SEEN}"
    case "${f}" in
        *bad*) kill -s SEGV $$ ;;
        *virus*) printf '%s: Eicar-Test-Signature FOUND\n' "${f}"; exit 1 ;;
    esac
done
exit 0
EOF
chmod 755 "${work}/bin/clamscan"
export HFU_BASE="${work}" HFU_SENT="${work}/sent.txt" HFU_SEEN="${work}/seen.txt" PATH="${work}/bin:${PATH}"
# shellcheck disable=SC1091
source "${root}/service/cron/watchdogs/common.sh"
sentence="$(hf_get_crash_sentence "AIDE" 139)"
printf '%s' "${sentence}" | grep -q 'signal 11'
printf '%s' "${sentence}" | grep -q 'erreur interne du programme'
LOG_FILE="${work}/clam.log"
ALERT_FILE="${work}/clam.txt"
: > "${LOG_FILE}"
list="${work}/list"
printf '/ok\0/bad\0/virus\0/after\0' > "${list}"
hf_list_clamav_scan "${list}" >> "${LOG_FILE}" 2>&1
grep -q 'clamscan planté signal 11 sur /bad' "${LOG_FILE}"
grep -q 'scan /after' "${HFU_SEEN}"
hf_report_clamav
kind="$(hf_get_clamav_kind "${LOG_FILE}")"
[[ "${kind}" == "infected" ]]
hf_log_alert "clamscan : infection(s) (voir ${LOG_FILE})"
grep -q 'Ce fichier n'"'"'a pas été analysé' "${HFU_SENT}"
grep -q 'clamscan planté signal 11 sur /bad' "${HFU_SENT}"
grep -q 'clamscan : infection(s)' "${HFU_SENT}"
grep -q 'Eicar-Test-Signature FOUND' "${HFU_SENT}"
: > "${HFU_SEEN}"
: > "${LOG_FILE}"
: > "${HFU_SENT}"
printf '/bad1\0/bad2\0/later\0' > "${list}"
hf_list_clamav_scan "${list}" >> "${LOG_FILE}" 2>&1
grep -q 'contrôle arrêté' "${LOG_FILE}"
! grep -q 'scan /later' "${HFU_SEEN}"
hf_report_clamav
grep -q 'deux fois de suite' "${HFU_SENT}"
grep -q 'fichiers restants n'"'"'ont pas été analysés' "${HFU_SENT}"
: > "${list}"
: > "${LOG_FILE}"
: > "${HFU_SENT}"
empty_rc=0
set +e
hf_list_clamav_scan "${list}" >> "${LOG_FILE}" 2>&1
empty_rc=$?
set -e
[[ "${empty_rc}" -eq 0 ]]
[[ ! -s "${HFU_SENT}" ]]
: > "${HFU_SENT}"
bash -c '
set -euo pipefail
export HFU_BASE="'"${work}"'" HFU_SENT="'"${HFU_SENT}"'"
source "'"${root}"'/service/cron/watchdogs/common.sh"
LOG_FILE="'"${work}"'/dead.log"
ALERT_FILE="'"${work}"'/dead.txt"
: > "${LOG_FILE}"
hf_arm_crash_mail "essai"
exit 3
' || true
grep -q "s'est arrêté (code 3)" "${HFU_SENT}"
CRASH
if [[ "${crash_rc}" -eq 0 ]]; then
    hft_pass "graph.crash-mail" "plantage nommé, suite du lot, infection encore signalée"
else
    hft_fail "graph.crash-mail" "le courrier de plantage ou d'infection n'a pas le texte attendu"
fi

hft_section "durcissement quotidien"
ssh_drop="${HFT_ROOT}/config/ssh/00-high-fortress-user.conf"
desk="${HFT_ROOT}/service/desktop/configure.sh"
brave="${HFT_ROOT}/config/desktop/brave-policy.json"
ufw_policy="${HFT_ROOT}/config/ufw/policy.conf"
usb="${HFT_ROOT}/service/usbguard/configure.sh"
reboot="${HFT_ROOT}/service/cron/watchdogs/reboot-notice.sh"
daily_ok=1
grep -q '^AllowTcpForwarding no$' "${ssh_drop}" || daily_ok=0
grep -q '^AllowAgentForwarding no$' "${ssh_drop}" || daily_ok=0
grep -q '^PasswordAuthentication yes$' "${ssh_drop}" || daily_ok=0
grep -q 'timestamp_timeout=5' "${HFT_ROOT}/system/configure.sh" || daily_ok=0
grep -q 'force_balanced_enabled' "${brave}" || daily_ok=0
grep -q 'DnsOverHttpsMode' "${brave}" || daily_ok=0
grep -q 'pgrep -x' "${reboot}" || daily_ok=0
if grep -qE 'systemctl reboot|shutdown' "${reboot}"; then
    daily_ok=0
fi
grep -q '03:\*:\*' "${usb}" || daily_ok=0
if grep -q 'usb-storage' "${usb}"; then
    daily_ok=0
fi
grep -q 'authorized_keys' "${HFT_ROOT}/service/aide/configure.sh" || daily_ok=0
grep -q '!/home/' "${HFT_ROOT}/config/aide/aide.conf" || daily_ok=0
awk '
    /out\.extend/ { ext = NR }
    /path\.write_text/ { wr = NR }
    END { exit !(ext && wr && wr > ext) }
' "${HFT_ROOT}/service/aide/configure.sh" || daily_ok=0
grep -q 'hfu-reboot-notice.timer' "${HFT_ROOT}/service/cron/configure.sh" || daily_ok=0
grep -q 'scope global' "${HFT_ROOT}/service/ufw/configure.sh" || daily_ok=0
grep -q 'SSH LAN' "${ufw_policy}" || daily_ok=0
grep -q 'HFU_UFW_DEFAULT_OUTGOING=allow' "${ufw_policy}" || daily_ok=0
grep -qF 'ufw default "${HFU_UFW_DEFAULT_OUTGOING}" outgoing' "${HFT_ROOT}/service/ufw/configure.sh" || daily_ok=0
if grep -q 'sleep-inactive' "${desk}"; then
    daily_ok=0
fi
for lang in en fr de es; do
    page="${HFT_ROOT}/docs/${lang}/README.md"
    grep -q 'AllowTcpForwarding no' "${page}" || daily_ok=0
    grep -q 'AllowAgentForwarding no' "${page}" || daily_ok=0
    grep -q 'PasswordAuthentication yes' "${page}" || daily_ok=0
    grep -q 'hfu-reboot-notice.timer' "${page}" || daily_ok=0
    grep -q 'usbguard' "${page}" || daily_ok=0
    grep -q 'force_balanced_enabled' "${page}" || daily_ok=0
    grep -q 'reboot-notice.sh' "${HFT_ROOT}/docs/${lang}/architecture.md" || daily_ok=0
done
if grep -q 'No other incoming allow rule is added.' "${HFT_ROOT}/docs/en/README.md"; then
    daily_ok=0
fi
ver="${HFT_ROOT}/verify/workstation.sh"
grep -q 'allowtcpforwarding' "${ver}" || daily_ok=0
grep -q 'allowagentforwarding' "${ver}" || daily_ok=0
grep -qF 'SSH (limit)' "${ver}" || daily_ok=0
grep -qF 'SSH LAN' "${ver}" || daily_ok=0
grep -q 'timestamp_timeout=5' "${ver}" || daily_ok=0
grep -q 'hfu-reboot-notice.timer' "${ver}" || daily_ok=0
grep -qF 'allow with-interface equals { 03:*:* }' "${ver}" || daily_ok=0
grep -qF '"DnsOverHttpsMode": "off"' "${ver}" || daily_ok=0
grep -qF 'mailnews.message_display.disable_remote_image' "${ver}" || daily_ok=0
grep -q 'LockDatabaseIdleSeconds' "${ver}" || daily_ok=0
grep -q 'uint32 1200' "${ver}" || daily_ok=0
grep -q 'verrou de session différent de 20 minutes' "${ver}" || daily_ok=0
grep -qF 'The same run checks SSH forwarding' "${HFT_ROOT}/docs/en/README.md" || daily_ok=0
grep -qF 'La même passe contrôle le relais SSH' "${HFT_ROOT}/docs/fr/README.md" || daily_ok=0
grep -qF 'Derselbe Lauf prüft die SSH-Weiterleitung' "${HFT_ROOT}/docs/de/README.md" || daily_ok=0
grep -qF 'La misma pasada comprueba el reenvío SSH' "${HFT_ROOT}/docs/es/README.md" || daily_ok=0
if [[ "${daily_ok}" -eq 1 ]]; then
    hft_pass "graph.daily" "relais SSH coupé, préfixes connectés, bureau, USB, avis de redémarrage"
else
    hft_fail "graph.daily" "le durcissement quotidien doit rester compatible avec le poste"
fi

hft_section "readme"
readme="${HFT_ROOT}/README.md"
en="${HFT_ROOT}/docs/en/README.md"
fr="${HFT_ROOT}/docs/fr/README.md"
pages_ok=1
for lang in en fr de es; do
    for page in README.md configuration.md surveillance.md architecture.md files.md logs.md; do
        if [[ ! -f "${HFT_ROOT}/docs/${lang}/${page}" ]]; then
            pages_ok=0
        elif [[ "${page}" != "README.md" ]] && ! head -1 "${HFT_ROOT}/docs/${lang}/${page}" | grep -q 'README.md'; then
            pages_ok=0
        fi
    done
done
for old in configuration.md surveillance.md architecture.md files.md logs.md; do
    [[ -f "${HFT_ROOT}/${old}" ]] && pages_ok=0
done
grep -qF '## Documentation' "${readme}" || pages_ok=0
grep -qF 'Click a flag to open all the information.' "${readme}" || pages_ok=0
grep -qF 'width="100%"' "${readme}" || pages_ok=0
grep -qF 'Do not copy it into a message, a ticket, or a repository.' "${readme}" && pages_ok=0
for flag in en fr de es; do
    [[ -f "${HFT_ROOT}/docs/flags/${flag}.svg" ]] || pages_ok=0
    grep -qF "docs/flags/${flag}.svg" "${readme}" || pages_ok=0
done
warn='`secrets.conf` stays on the machine. Do not copy it into a message, a ticket, or a repository.'
desc_lines=0
while IFS= read -r line; do
    line="${line//${warn}/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "${line}" ]] && continue
    desc_lines=$((desc_lines + 1))
    grep -qF "${line}" "${readme}" || pages_ok=0
done < <(awk '
    /^## Description$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "${en}")
[[ "${desc_lines}" -ge 2 ]] || pages_ok=0
if grep -qF '# High-Fortress User' "${readme}" \
   && grep -qF 'https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh' "${readme}" \
   && grep -qF 'ca-certificates curl git swaks tar' "${readme}" \
   && grep -qF 'docs/en/README.md' "${readme}" \
   && grep -qF 'docs/fr/README.md' "${readme}" \
   && grep -qF 'docs/de/README.md' "${readme}" \
   && grep -qF 'docs/es/README.md' "${readme}" \
   && ! grep -qF '## Avant de commencer' "${readme}" \
   && ! grep -R -qF 'disable_ipv6' "${HFT_ROOT}/docs" \
   && ! grep -R -qF 'PasswordAuthentication no' "${HFT_ROOT}/docs" \
   && grep -qF 'Ne le copiez pas dans un message, un ticket ou un dépôt.' "${fr}" \
   && grep -qF 'HF_LYNIS_MIN_SCORE' "${en}" \
   && grep -qF 'is 80' "${en}" \
   && awk '
        /^## Description$/ { h[++n] = NR }
        /^## Before you start$/ { h[++n] = NR }
        /^## Installation$/ { h[++n] = NR }
        /^## What configure.sh does$/ { h[++n] = NR }
        /^## Installed software and services$/ { h[++n] = NR }
        /^## What the machine does after installation$/ { h[++n] = NR }
        /^## Alert emails$/ { h[++n] = NR }
        /^## Commands after installation$/ { h[++n] = NR }
        /^## Detailed pages$/ { h[++n] = NR }
        END {
            if (n != 9) exit 1
            for (i = 2; i <= n; i++) if (h[i] <= h[i-1]) exit 1
        }
      ' "${en}" \
   && awk '
        /^## Description$/ { h[++n] = NR }
        /^## Avant de commencer$/ { h[++n] = NR }
        /^## Installation$/ { h[++n] = NR }
        /^## Action de configure.sh$/ { h[++n] = NR }
        /^## Logiciels et services installés$/ { h[++n] = NR }
        /^## Ce que la machine fait après l'"'"'installation$/ { h[++n] = NR }
        /^## E-mails d'"'"'alerte$/ { h[++n] = NR }
        /^## Commandes après l'"'"'installation$/ { h[++n] = NR }
        /^## Fichiers détaillés$/ { h[++n] = NR }
        END {
            if (n != 9) exit 1
            for (i = 2; i <= n; i++) if (h[i] <= h[i-1]) exit 1
        }
      ' "${fr}" \
   && [[ "${pages_ok}" -eq 1 ]]; then
    hft_pass "graph.readme" "squelette du README et pages liées"
else
    hft_fail "graph.readme" "le README du poste doit suivre agents/laws/readme.md"
fi
