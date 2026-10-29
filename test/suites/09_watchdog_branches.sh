#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/09_watchdog_branches.sh
# Updated at : 2026-10-29
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Run each workstation watchdog branch in a sandbox.
# -----------------------------------------------------------------------------

t_section "branches des contrôles poste"

holder_pid=""
work=""
bin=""
base=""
parent="$(cd -- "${T_ROOT}/.." && pwd)"
probe="${parent}/scripts/vm-probe.sh"

t_stop_holder() {
    if [[ -n "${holder_pid}" ]]; then
        kill -TERM "${holder_pid}" 2>/dev/null || true
        wait "${holder_pid}" 2>/dev/null || true
        holder_pid=""
    fi
}

t_link_tools() {
    local dest="$1"
    local name src
    mkdir -p "${dest}"
    for name in bash sha256sum sort install mktemp date grep head stat awk basename cmp comm cat cp chmod mkdir rm ln dirname readlink tee python3 sleep mv tr sed cut; do
        src="$(type -P "${name}" || true)"
        if [[ -n "${src}" ]]; then
            ln -sfn "${src}" "${dest}/${name}"
        fi
    done
}

t_prepare_user() {
    local name="$1"
    t_stop_holder
    work="${G_ARTIFACTS}/branch/${name}"
    rm -rf "${work}"
    base="${work}/base"
    bin="${base}/cron/bin"
    mkdir -p "${bin}" "${work}/path" "${work}/run" "${work}/samples" "${work}/bin" "${work}/quarantine"
    t_link_tools "${work}/path"
    cp "${T_ROOT}/service/cron/watchdogs/common.sh" "${bin}/common.sh"
    cp "${T_ROOT}/service/cron/watchdogs/${name}" "${bin}/${name}"
    chmod 755 "${bin}/${name}"
    cat > "${bin}/watchdog.sh" << EOF
g_log_alert() { printf '%s\n' "\$*" >> "${base}/alert.log"; }
g_get_crash_sentence() { printf 'crash %s %s' "\$1" "\$2"; }
g_arm_crash_mail() { :; }
g_run_limited() { "\$@"; }
EOF
    cat > "${work}/path/lsof" << EOF
#!/bin/bash
if [[ -s "${work}/holder.pid" ]]; then
    cat "${work}/holder.pid"
fi
exit 0
EOF
    chmod 755 "${work}/path/lsof"
    printf '%s\n' '#!/bin/bash' 'exit 0' > "${work}/path/fuser"
    chmod 755 "${work}/path/fuser"
    printf '%s\n' '#!/bin/bash' 'exit 0' > "${work}/path/logger"
    chmod 755 "${work}/path/logger"
    cat > "${work}/path/id" << 'EOF'
#!/bin/bash
if [[ "${1:-}" == "clamav" ]]; then
    exit 1
fi
exec /usr/bin/id "$@"
EOF
    chmod 755 "${work}/path/id"
    cat > "${work}/path/systemctl" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "${work}/systemctl.log"
exit 0
EOF
    chmod 755 "${work}/path/systemctl"
    cat > "${work}/path/systemd-run" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "${work}/systemd-run.log"
exit 0
EOF
    chmod 755 "${work}/path/systemd-run"
    cat > "${work}/path/nft" << EOF
#!/bin/bash
printf '%s\n' "\$*" >> "${work}/nft.log"
exit 0
EOF
    chmod 755 "${work}/path/nft"
}

t_write_runner() {
    local script="$1"
    local extra="${2:-}"
    cat > "${work}/run.sh" << EOF
#!/usr/bin/env bash
export PATH="${work}/path"
export W_BASE="${base}"
export W_CLAMAV_QUARANTINE_DIR="${work}/quarantine"
${extra}
set +e
/usr/bin/bash "${script}" > "${work}/stdout.txt" 2> "${work}/stderr.txt"
printf '%s\n' "\$?" > "${work}/status"
EOF
}

t_box() {
    local proc_bind="${1:-}"
    local -a args
    args=(
        --die-with-parent
        --ro-bind / /
        --bind "${work}" "${work}"
        --tmpfs /tmp
        --bind "${work}/run" /run
        --dev /dev
        --setenv PATH "${work}/path"
        --setenv HOME "${work}"
        --setenv W_BASE "${base}"
    )
    if [[ -n "${proc_bind}" ]]; then
        args+=(--bind "${proc_bind}" /proc)
    else
        args+=(--proc /proc)
    fi
    bwrap "${args[@]}" /usr/bin/bash "${work}/run.sh"
}

t_run_user() {
    local script="$1"
    local proc_bind="${2:-}"
    local extra="${3:-}"
    t_write_runner "${script}" "${extra}"
    if ! t_box "${proc_bind}"; then
        printf '%s\n' "bwrap" > "${work}/status"
    fi
}

t_got_status() {
    cat "${work}/status" 2>/dev/null || printf '%s\n' "missing"
}

t_stdout_has() {
    grep -F -q -- "$1" "${work}/stdout.txt" 2>/dev/null
}

t_alert_has() {
    grep -F -q -- "$1" "${base}/alert.log" 2>/dev/null
}

t_log_has() {
    grep -R -F -q -- "$1" "${base}/cron/security_logs" 2>/dev/null
}

t_start_holder() {
    local name="$1"
    local exe="${work}/bin/${name}"
    local tries=0
    # Bash execs a lone sleep and renames itself. read returns when input ends.
    cp "$(type -P python3)" "${exe}"
    chmod 755 "${exe}"
    "${exe}" -c 'import time; time.sleep(120)' </dev/null &
    holder_pid=$!
    printf '%s\n' "${holder_pid}" > "${work}/holder.pid"
    until [[ -r "/proc/${holder_pid}/comm" ]] || [[ "${tries}" -ge 50 ]]; do
        sleep 0.02
        tries=$((tries + 1))
    done
}

t_ausearch_stub() {
    local code="$1"
    local body="$2"
    cat > "${work}/path/ausearch" << EOF
#!/bin/bash
printf '%s\n' "${body}"
exit ${code}
EOF
    chmod 755 "${work}/path/ausearch"
}

t_journal_stub() {
    local body="$1"
    cat > "${work}/path/journalctl" << EOF
#!/bin/bash
printf '%s\n' "${body}"
exit 0
EOF
    chmod 755 "${work}/path/journalctl"
}

if ! command -v bwrap >/dev/null 2>&1; then
    t_fail "branch.bwrap" "bwrap absent"
else
    t_pass "branch.bwrap" "bwrap présent"
fi

t_prepare_user integrity.sh
t_run_user "${bin}/integrity.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "liste d'intégrité absente" && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.integrity.missing" "liste absente, pas de courrier"
else
    t_fail "branch.usr.integrity.missing" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user integrity.sh
printf 'alpha\n' > "${base}/file-a"
mkdir -p "${base}/src/config/integrity"
cat > "${base}/src/config/integrity/paths.list" << EOF
# comment
/no/such/liltress-file
${base}/file-a
EOF
t_run_user "${bin}/integrity.sh"
stamp="${base}/cron/integrity.sha256"
mode="$(stat -c '%a' "${stamp}" 2>/dev/null || echo missing)"
lines="$(grep -c . "${stamp}" 2>/dev/null || echo 0)"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "empreinte initiale écrite" \
    && [[ "${mode}" == "600" ]] && [[ "${lines}" == "1" ]] && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.integrity.first" "empreinte initiale, mode 600"
    t_pass "branch.usr.integrity.skip" "un seul fichier retenu"
else
    t_fail "branch.usr.integrity.first" "statut $(t_got_status) mode ${mode} lignes ${lines} $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
    t_fail "branch.usr.integrity.skip" "lignes ${lines}"
fi
saved="$(mktemp)"
cp "${stamp}" "${saved}"
t_run_user "${bin}/integrity.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "intégrité inchangée" && cmp -s "${saved}" "${stamp}" && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.integrity.same" "empreinte inchangée"
else
    t_fail "branch.usr.integrity.same" "statut $(t_got_status)"
fi
printf 'beta\n' > "${base}/file-a"
t_run_user "${bin}/integrity.sh"
if [[ "$(t_got_status)" == "0" ]] && t_alert_has "intégrité : empreinte modifiée" && ! cmp -s "${saved}" "${stamp}"; then
    t_pass "branch.usr.integrity.change" "courrier"
else
    t_fail "branch.usr.integrity.change" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi
rm -f "${saved}"

t_prepare_user behavior.sh
rm -f "${work}/path/ausearch"
t_run_user "${bin}/behavior.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "ausearch absent" && [[ ! -e "${base}/cron/behavior.stamp" ]] && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.behavior.absent" "ausearch absent"
else
    t_fail "branch.usr.behavior.absent" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user behavior.sh
printf '%s\n' 'nope' > "${base}/cron/behavior.stamp"
t_ausearch_stub 0 "unused"
t_run_user "${bin}/behavior.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "repère initial écrit" \
    && grep -Eq '^[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "${base}/cron/behavior.stamp" \
    && [[ "$(stat -c '%a' "${base}/cron/behavior.stamp")" == "600" ]]; then
    t_pass "branch.usr.behavior.stamp" "repère réécrit"
else
    t_fail "branch.usr.behavior.stamp" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user behavior.sh
printf '%s\n' '01/02/2026 03:04:05' > "${base}/cron/behavior.stamp"
cp "${base}/cron/behavior.stamp" "${work}/saved.stamp"
t_ausearch_stub 1 "no match"
t_run_user "${bin}/behavior.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "aucune exécution temporaire" \
    && ! cmp -s "${work}/saved.stamp" "${base}/cron/behavior.stamp" && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.behavior.clean" "silence et repère avancé"
else
    t_fail "branch.usr.behavior.clean" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user behavior.sh
printf '%s\n' '01/02/2026 03:04:05' > "${base}/cron/behavior.stamp"
cp "${base}/cron/behavior.stamp" "${work}/saved.stamp"
t_ausearch_stub 130 "boom"
t_run_user "${bin}/behavior.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "aucune exécution temporaire" \
    && ! cmp -s "${work}/saved.stamp" "${base}/cron/behavior.stamp" && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.behavior.nonzero" "échec ausearch, pas de courrier"
else
    t_fail "branch.usr.behavior.nonzero" "statut $(t_got_status)"
fi

t_prepare_user behavior.sh
printf '%s\n' '01/02/2026 03:04:05' > "${base}/cron/behavior.stamp"
t_ausearch_stub 0 "type=EXECVE key=exec-tmp"
t_run_user "${bin}/behavior.sh"
if [[ "$(t_got_status)" == "0" ]] && t_alert_has "exécution depuis un répertoire temporaire"; then
    t_pass "branch.usr.behavior.hit" "courrier"
else
    t_fail "branch.usr.behavior.hit" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
rm -f "${work}/path/journalctl"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "journalctl absent" && [[ ! -e "${base}/cron/egress.stamp" ]]; then
    t_pass "branch.usr.egress.absent" "journalctl absent"
else
    t_fail "branch.usr.egress.absent" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
printf '%s\n' 'nope' > "${base}/cron/egress.stamp"
t_journal_stub "unused"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "repère initial écrit" \
    && grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "${base}/cron/egress.stamp"; then
    t_pass "branch.usr.egress.stamp" "repère réécrit"
else
    t_fail "branch.usr.egress.stamp" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
cp "${base}/cron/egress.stamp" "${work}/saved.stamp"
t_journal_stub "kernel: nothing"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "aucun flux sortant inattendu" \
    && ! cmp -s "${work}/saved.stamp" "${base}/cron/egress.stamp" && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.egress.clean" "silence et repère avancé"
else
    t_fail "branch.usr.egress.clean" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
t_journal_stub "w-egress OUT=eth0"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "aucun flux sortant suspect" && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.egress.plain" "ligne sans exécutable, pas de courrier"
else
    t_fail "branch.usr.egress.plain" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
t_journal_stub "$(printf '%s\n' \
    'oct. 25 06:10:42 host kernel: w-egress IN= OUT=lo SRC=127.0.0.1 DST=224.0.0.251 PROTO=UDP SPT=5353 DPT=5353' \
    'oct. 25 06:10:43 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=224.0.0.251 PROTO=UDP SPT=5353 DPT=5353' \
    'oct. 25 06:10:53 host kernel: w-egress IN= OUT=enp1s0 SRC=fe80::1 DST=ff02:0000:0000:0000:0000:0000:0000:00fb PROTO=UDP SPT=5353 DPT=5353' \
    'oct. 25 06:10:43 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=185.125.190.122 PROTO=TCP SPT=46814 DPT=4460' \
    'oct. 25 06:10:44 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=192.168.122.255 PROTO=UDP SPT=47406 DPT=161' \
    'oct. 25 06:11:54 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=91.189.91.111 PROTO=UDP SPT=50257 DPT=123' \
    'oct. 25 06:12:00 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=192.168.122.1 PROTO=UDP SPT=68 DPT=67' \
    'oct. 25 06:12:01 host kernel: w-egress IN= OUT=enp1s0 SRC=fe80::1 DST=ff02::1:2 PROTO=UDP SPT=546 DPT=547')"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "aucun flux sortant inattendu" && [[ ! -e "${base}/alert.log" ]]; then
    t_pass "branch.usr.egress.routine" "mDNS NTP DHCP SNMP sans courrier"
else
    t_fail "branch.usr.egress.routine" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
t_journal_stub "$(printf '%s\n' \
    'oct. 25 06:10:42 host kernel: w-egress IN= OUT=lo SRC=127.0.0.1 DST=224.0.0.251 PROTO=UDP SPT=5353 DPT=5353' \
    'oct. 25 06:11:54 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=91.189.91.111 PROTO=UDP SPT=50257 DPT=123' \
    'oct. 25 06:12:10 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=203.0.113.10 PROTO=UDP SPT=47406 DPT=161' \
    'oct. 25 06:12:11 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=1.2.3.4 PROTO=TCP SPT=40000 DPT=587')"
t_ausearch_stub 0 "$(printf '%s\n' \
    'type=SYSCALL msg=audit(1.1:1): arch=c000003e syscall=42 success=yes comm="mail" exe="/usr/bin/swaks" pid=20 uid=1000' \
    'type=SOCKADDR msg=audit(1.1:1): saddr=0200024B01020304')"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_stdout_has "aucun flux sortant suspect" \
    && [[ ! -e "${base}/alert.log" ]] && ! t_log_has "DPT=587"; then
    t_pass "branch.usr.egress.mixed" "port inhabituel sans signal, pas de courrier"
else
    t_fail "branch.usr.egress.mixed" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
printf '%s\n' 'W_NET_ISOLATE_SEC=45' > "${base}/cron/egress.conf"
t_journal_stub "oct. 25 06:20:00 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=203.0.113.50 PROTO=TCP SPT=40000 DPT=4444"
t_ausearch_stub 0 "$(printf '%s\n' \
    'type=SYSCALL msg=audit(1.1:2): arch=c000003e syscall=42 success=yes comm="evil" exe="/tmp/evil" pid=30 uid=1000' \
    'type=SOCKADDR msg=audit(1.1:2): saddr=0200115CCB007132')"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_alert_has "flux sortant suspect bloqué" \
    && t_log_has "203.0.113.50 tcp/4444 pendant 45s" \
    && t_log_has "/tmp/evil" \
    && grep -q '203.0.113.50 . tcp . 4444 timeout 45s' "${work}/nft.log" \
    && ! grep -q 'w_isolate' "${work}/nft.log"; then
    t_pass "branch.usr.egress.suspect" "destination tenue 45 s"
else
    t_fail "branch.usr.egress.suspect" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true) $(tr '\n' ' ' < "${work}/nft.log" 2>/dev/null || true)"
fi

t_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
printf '%s\n' 'W_NET_ISOLATE_SEC=10' > "${base}/cron/egress.conf"
printf '%s\n' $'20261025-010101-1-curl\t2026-10-25T01:01:01+02:00\tclamav\t/usr/bin/curl\t/var/lib/clamav/quarantine/20261025-010101-1-curl\tEicar' > "${base}/cron/quarantine.registry"
t_journal_stub "oct. 25 06:21:00 host kernel: w-egress IN= OUT=enp1s0 SRC=192.168.122.110 DST=198.51.100.8 PROTO=TCP SPT=41000 DPT=8443"
t_ausearch_stub 0 "$(printf '%s\n' \
    'type=SYSCALL msg=audit(1.1:3): arch=c000003e syscall=42 success=yes comm="curl" exe="/usr/bin/curl" pid=31 uid=1000' \
    'type=SOCKADDR msg=audit(1.1:3): saddr=020020FBC6336408')"
t_run_user "${bin}/egress-watch.sh"
if [[ "$(t_got_status)" == "0" ]] && t_alert_has "flux sortant suspect bloqué" \
    && t_log_has "198.51.100.8 tcp/8443 pendant 120s" \
    && grep -q '198.51.100.8 . tcp . 8443 timeout 120s' "${work}/nft.log"; then
    t_pass "branch.usr.egress.quarantine" "binaire en quarantaine, durée plancher"
else
    t_fail "branch.usr.egress.quarantine" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true) $(tr '\n' ' ' < "${work}/nft.log" 2>/dev/null || true)"
fi

t_prepare_user boot-scan.sh
order_names=(apply-scan-skip.sh aide.sh integrity.sh rkhunter.sh behavior.sh chkrootkit.sh clamav.sh debsums.sh egress-watch.sh)
for name in "${order_names[@]}"; do
    if [[ "${name}" == "rkhunter.sh" ]]; then
        code=1
    else
        code=0
    fi
    cat > "${bin}/${name}" << EOF
#!/bin/bash
printf '%s\n' "${name}" >> "${work}/trace"
exit ${code}
EOF
    chmod 755 "${bin}/${name}"
done
t_run_user "${bin}/boot-scan.sh"
expected="$(printf '%s\n' "${order_names[@]}")"
if [[ "$(t_got_status)" == "0" ]] && [[ "$(cat "${work}/trace" 2>/dev/null || true)" == "${expected}" ]]; then
    t_pass "branch.usr.boot.order" "neuf contrôles"
else
    t_fail "branch.usr.boot.order" "$(tr '\n' ' ' < "${work}/trace" 2>/dev/null || true) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi
if t_alert_has "crash rkhunter 1"; then
    t_pass "branch.usr.boot.continue" "échec puis suite"
else
    t_fail "branch.usr.boot.continue" "courrier absent"
fi

t_prepare_user clamav-event.sh
sample="${work}/samples/.clamav-quarantine-lock.1"
printf 'lock\n' > "${sample}"
t_run_user "${bin}/clamav-event.sh" "" "export CLAM_VIRUSEVENT_FILENAME=${sample}
export CLAM_VIRUSEVENT_VIRUSNAME=Eicar"
if [[ "$(t_got_status)" == "0" ]] && [[ ! -e "${base}/alert.log" ]] && ! t_log_has "quarantaine"; then
    t_pass "branch.usr.clamav.lock" "verrou avant la réponse"
else
    t_fail "branch.usr.clamav.lock" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
: > "${work}/holder.pid"
t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "déplacé en quarantaine" \
    && [[ -n "$(find "${work}/quarantine" -type f -print)" ]] \
    && grep -q 'w_isolate' "${work}/nft.log" && grep -q 'dport 53' "${work}/nft.log" \
    && grep -q 'reject' "${work}/nft.log" && grep -q -- '--on-active=120' "${work}/systemd-run.log"; then
    t_pass "branch.usr.response.move" "fichier en quarantaine"
    t_pass "branch.usr.response.nft" "isolation 120"
else
    t_fail "branch.usr.response.move" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
    t_fail "branch.usr.response.nft" "$(tr '\n' ' ' < "${work}/nft.log" 2>/dev/null || true)"
fi

t_prepare_user clamav-response.sh
t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${work}/samples/missing.txt
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "fichier déjà absent"; then
    t_pass "branch.usr.response.absent" "fichier déjà absent"
else
    t_fail "branch.usr.response.absent" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
printf '1\n' > "${work}/holder.pid"
t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "pid 1"; then
    t_pass "branch.usr.response.pid1" "pid 1 conservé"
else
    t_fail "branch.usr.response.pid1" "statut $(t_got_status)"
fi

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
printf '42424242\n' > "${work}/holder.pid"
t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "uid 0"; then
    t_pass "branch.usr.response.uid" "uid 0 conservé"
else
    t_fail "branch.usr.response.uid" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
mkdir -p "${work}/fakeproc/42424242"
: > "${work}/fakeproc/42424242/comm"
printf '42424242\n' > "${work}/holder.pid"
t_run_user "${bin}/clamav-response.sh" "${work}/fakeproc" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "nom absent"; then
    t_pass "branch.usr.response.empty" "nom vide conservé"
else
    t_fail "branch.usr.response.empty" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
t_start_holder gamescope
t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "non arrêté : gamescope" && kill -0 "${holder_pid}" 2>/dev/null; then
    t_pass "branch.usr.response.deny" "gamescope conservé"
else
    t_fail "branch.usr.response.deny" "statut $(t_got_status) $(grep -R -F -h 'processus' "${base}/cron/security_logs" 2>/dev/null | tr '\n' ' ')"
fi
t_stop_holder

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
t_start_holder worker
t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has ") arrêté" && ! kill -0 "${holder_pid}" 2>/dev/null; then
    t_pass "branch.usr.response.term" "TERM envoyé"
else
    t_fail "branch.usr.response.term" "statut $(t_got_status) $(grep -R -F -h 'processus' "${base}/cron/security_logs" 2>/dev/null | tr '\n' ' ')"
fi
t_stop_holder

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
mkdir -p "${work}/fakeproc/42424242"
printf '%s' 'worker' > "${work}/fakeproc/42424242/comm"
printf '42424242\n' > "${work}/holder.pid"
t_run_user "${bin}/clamav-response.sh" "${work}/fakeproc" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "signal refusé"; then
    t_pass "branch.usr.response.refused" "signal refusé"
else
    t_fail "branch.usr.response.refused" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
rm -f "${work}/path/nft"
t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${sample}
export W_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(t_got_status)" == "0" ]] && t_log_has "nft absent" && [[ ! -e "${work}/nft.log" ]]; then
    t_pass "branch.usr.response.nft-absent" "nft absent"
else
    t_fail "branch.usr.response.nft-absent" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_check_user_sec() {
    local id="$1"
    local raw="$2"
    local expect="$3"
    t_prepare_user clamav-response.sh
    printf 'note\n' > "${work}/samples/note.txt"
    printf 'W_NET_ISOLATE_SEC=%s\n' "${raw}" > "${base}/cron/egress.conf"
    t_run_user "${bin}/clamav-response.sh" "" "export W_CLAMAV_EVENT_FILE=${work}/samples/note.txt
export W_CLAMAV_EVENT_VIRUS=Eicar"
    if [[ "$(t_got_status)" == "0" ]] && t_log_has "isolation ${expect}s" \
        && grep -q -- "--on-active=${expect}" "${work}/systemd-run.log"; then
        t_pass "${id}" "durée ${expect}"
    else
        t_fail "${id}" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/systemd-run.log" 2>/dev/null || true)"
    fi
}
t_check_user_sec branch.usr.response.clamp-low 10 120
t_check_user_sec branch.usr.response.clamp-high 400 120
t_check_user_sec branch.usr.response.sec 45 45

t_prepare_user egress-watch.sh
cat > "${work}/probe.sh" << EOF
#!/usr/bin/env bash
set +e
export W_BASE="${base}"
export W_CLAMAV_QUARANTINE_DIR="${work}/quarantine"
source "${parent}/core/watchdog.sh"
result="${work}/quarantine-result.txt"
: > "\${result}"
sample="${work}/samples/plain.txt"
printf 'plain\n' > "\${sample}"
log="${work}/warn.log"
printf '%s\n' "Rootkit Hunter version 1.4.6" "Warning: The file properties have changed" "\${sample}" > "\${log}"
: > "${work}/holder.pid"
g_quarantine_confirmed_log rkhunter "\${log}" systemd sshd unbound fail2ban gamescope > "${work}/warn.out"
if [[ "\${G_CONFIRMED_COUNT}" -eq 0 ]] && [[ ! -e "${base}/cron/quarantine.registry" ]] && [[ -f "\${sample}" ]]; then
    printf '%s\n' "warn-ok" >> "\${result}"
fi
evil="${work}/samples/evil.bin"
printf 'evil\n' > "\${evil}"
printf '%s\n' "INFECTED: \${evil}" > "\${log}"
g_quarantine_confirmed_log rkhunter "\${log}" systemd sshd unbound fail2ban gamescope > "${work}/move.out"
if [[ ! -e "\${evil}" ]] && grep -q "\${evil}" "${base}/cron/quarantine.registry" && grep -q 'quarantine-restore.sh' "${base}/cron/quarantine.pending"; then
    printf '%s\n' "move-ok" >> "\${result}"
fi
g_take_quarantine_note
if printf '%s\n' "\${NOTE_CMD}" | grep -q 'quarantine-restore.sh' && [[ ! -e "${base}/cron/quarantine.pending" ]]; then
    printf '%s\n' "take-ok" >> "\${result}"
fi
printf '%s\n' "INFECTED: /etc/passwd" > "\${log}"
g_quarantine_confirmed_log rkhunter "\${log}" systemd sshd unbound fail2ban gamescope > "${work}/prot.out"
if [[ -f /etc/passwd ]] && grep -q 'non mis en quarantaine' "${work}/prot.out" && ! grep -q '/etc/passwd' "${base}/cron/quarantine.registry"; then
    printf '%s\n' "prot-ok" >> "\${result}"
fi
held="${work}/samples/held.bin"
printf 'held\n' > "\${held}"
printf '1\n' > "${work}/holder.pid"
printf '%s\n' "Rootkit \${held}" > "\${log}"
g_quarantine_confirmed_log rkhunter "\${log}" systemd sshd unbound fail2ban gamescope > "${work}/pid.out"
if [[ -f "\${held}" ]] && grep -q 'non mis en quarantaine : pid 1' "${work}/pid.out"; then
    printf '%s\n' "pid-ok" >> "\${result}"
fi
printf '%s\n' 'oct. 22 06:20:42 host kernel: w-egress IN= OUT=eth0 SRC=10.0.0.1 DST=74.125.206.109 PROTO=TCP SPT=34730 DPT=587' 'oct. 22 06:20:42 host kernel: w-egress IN= OUT=eth0 SRC=10.0.0.1 DST=74.125.206.109 PROTO=TCP SPT=34730 DPT=587' 'oct. 22 06:20:43 host kernel: w-egress IN= OUT=eth0 SRC=10.0.0.1 DST=1.2.3.4 PROTO=TCP SPT=9 DPT=9' > "${work}/kern.txt"
printf '%s\n' 'type=SYSCALL msg=audit(1.1:1): arch=c000003e syscall=42 success=yes comm="curl" pid=1842 uid=1000' 'type=SOCKADDR msg=audit(1.1:1): saddr=0200024B4A7DCE6D' > "${work}/audit.txt"
g_format_egress_body "${work}/kern.txt" "${work}/audit.txt" > "${work}/egress.out"
if grep -q 'Processus : curl (pid 1842) uid 1000' "${work}/egress.out" && grep -q 'Processus : non associé' "${work}/egress.out" && [[ "\$(grep -c 'DPT=587' "${work}/egress.out")" -eq 1 ]]; then
    printf '%s\n' "egress-ok" >> "\${result}"
fi
g_format_egress_body "${work}/kern.txt" "" > "${work}/egress-plain.out"
if grep -q 'w-egress' "${work}/egress-plain.out" && ! grep -q 'Processus' "${work}/egress-plain.out"; then
    printf '%s\n' "plain-ok" >> "\${result}"
fi
restore_out="\$(bash "${parent}/core/quarantine-restore.sh" 20261022-010101-1-evil 2>&1)"
restore_rc=\$?
if [[ "\${restore_rc}" -eq 1 ]] && printf '%s\n' "\${restore_out}" | grep -Eq 'root requis|identifiant absent du registre'; then
    printf '%s\n' "restore-ok" >> "\${result}"
fi
exit 0
EOF
chmod 755 "${work}/probe.sh"
t_run_user "${work}/probe.sh"
if [[ "$(t_got_status)" == "0" ]] \
    && grep -qx 'warn-ok' "${work}/quarantine-result.txt" \
    && grep -qx 'move-ok' "${work}/quarantine-result.txt" \
    && grep -qx 'take-ok' "${work}/quarantine-result.txt" \
    && grep -qx 'prot-ok' "${work}/quarantine-result.txt" \
    && grep -qx 'pid-ok' "${work}/quarantine-result.txt" \
    && grep -qx 'egress-ok' "${work}/quarantine-result.txt" \
    && grep -qx 'plain-ok' "${work}/quarantine-result.txt" \
    && grep -qx 'restore-ok' "${work}/quarantine-result.txt"; then
    t_pass "branch.usr.quarantine" "registre, chemin protégé et processus du flux"
else
    t_fail "branch.usr.quarantine" "statut $(t_got_status) $(tr '\n' ' ' < "${work}/quarantine-result.txt" 2>/dev/null || true) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

t_stop_holder

t_section "chemins AIDE dans l'alerte"
# shellcheck disable=SC1091
source "${parent}/core/watchdog.sh"
work="${G_ARTIFACTS}/branch/aide-paths"
rm -rf "${work}"
mkdir -p "${work}"
{
    cat << 'EOF'
Start timestamp: 2026-10-29 06:43:48 +0100 (AIDE 0.19.3)
AIDE found differences between database and filesystem!!
Summary:
  Total number of entries:	43538
  Added entries:		3
  Removed entries:		1
  Changed entries:		2
Added entries:
l++++++++++++++++++: /etc/systemd/system/multi-user.target.wants/snap-gnome\x2d46\x2d2404-177.mount
f++++++++++++++++++: /etc/systemd/system/snap-gnome\x2d46\x2d2404-177.mount
l++++++++++++++++++: /etc/systemd/system/snapd.mounts.target.wants/snap-gnome\x2d46\x2d2404-177.mount
Removed entries:
d------------------: /etc/removed-dir
Changed entries:
d =.p.u : /etc/changed-dir
f >b... mc.C . .: /etc/changed file.txt
c++++++++++++++++: /dev/added-char
b----------------: /dev/removed-block
p++++++++++++++++: /tmp/added.fifo
s++++++++++++++++: /tmp/added.sock
D++++++++++++++++: /tmp/added.door
P++++++++++++++++: /tmp/added.port
!++++++++++++++++: /tmp/type-changed
?++++++++++++++++: /tmp/unknown-type
added: /etc/plain added.txt
removed: /etc/plain removed.txt
changed: /etc/plain changed.txt
Detailed information about changes:
Directory: /etc/changed-dir
 Perm      : 755 | 700
Link: /etc/link-detail
 Linkname  : old | new
File: /etc/file-detail
 Size      : 1 | 2
 SHA256    : abcdef-file-hash
Block device: /dev/sda
Character device: /dev/null
FIFO: /tmp/fifo-detail
Socket: /tmp/sock-detail
Door: /tmp/door-detail
Port: /tmp/port-detail
Unknown file type: /tmp/unknown-detail
Entry /etc/attr-set in databases has different attributes: +acl
EOF
    n=1
    while [[ "${n}" -le 45 ]]; do
        printf ' Size      : %s | %s\n' "${n}" "$((n + 1))"
        n=$((n + 1))
    done
    n=1
    while [[ "${n}" -le 130 ]]; do
        printf 'f++++++++++++++++++: /etc/bulk/file-%s\n' "${n}"
        n=$((n + 1))
    done
    cat << 'EOF'
The attributes of the (uncompressed) database(s):
/var/lib/aide/aide.db
 SHA256    : eD+Jr7xjbH8fbRgwNs1lvk2rdR69LOE0
End timestamp: 2026-10-29 06:44:08 +0100 (run time: 0m 20s)
EOF
} > "${work}/aide-sample.log"
excerpt="$(g_get_alert_excerpt "${work}/aide-sample.log")"
printf '%s\n' "${excerpt}" > "${work}/excerpt.txt"
aide_ok=1
for path in \
    'l++++++++++++++++++: /etc/systemd/system/multi-user.target.wants/snap-gnome\x2d46\x2d2404-177.mount' \
    'f++++++++++++++++++: /etc/systemd/system/snap-gnome\x2d46\x2d2404-177.mount' \
    'l++++++++++++++++++: /etc/systemd/system/snapd.mounts.target.wants/snap-gnome\x2d46\x2d2404-177.mount' \
    'd------------------: /etc/removed-dir' \
    'd =.p.u : /etc/changed-dir' \
    'f >b... mc.C . .: /etc/changed file.txt' \
    'c++++++++++++++++: /dev/added-char' \
    'b----------------: /dev/removed-block' \
    'p++++++++++++++++: /tmp/added.fifo' \
    's++++++++++++++++: /tmp/added.sock' \
    'D++++++++++++++++: /tmp/added.door' \
    'P++++++++++++++++: /tmp/added.port' \
    '!++++++++++++++++: /tmp/type-changed' \
    '?++++++++++++++++: /tmp/unknown-type' \
    'added: /etc/plain added.txt' \
    'removed: /etc/plain removed.txt' \
    'changed: /etc/plain changed.txt' \
    'Directory: /etc/changed-dir' \
    'Link: /etc/link-detail' \
    'File: /etc/file-detail' \
    'Block device: /dev/sda' \
    'Character device: /dev/null' \
    'FIFO: /tmp/fifo-detail' \
    'Socket: /tmp/sock-detail' \
    'Door: /tmp/door-detail' \
    'Port: /tmp/port-detail' \
    'Unknown file type: /tmp/unknown-detail' \
    'Entry /etc/attr-set in databases has different attributes: +acl' \
    'f++++++++++++++++++: /etc/bulk/file-1' \
    'f++++++++++++++++++: /etc/bulk/file-130'
do
    grep -Fxq "${path}" "${work}/excerpt.txt" || aide_ok=0
done
grep -Fq 'abcdef-file-hash' "${work}/excerpt.txt" || aide_ok=0
grep -Fq "ligne(s) d'attribut supplémentaire(s) non recopiées" "${work}/excerpt.txt" || aide_ok=0
[[ "$(grep -c '/etc/bulk/file-' "${work}/excerpt.txt")" -eq 130 ]] || aide_ok=0
grep -Fq '/var/lib/aide/aide.db' "${work}/excerpt.txt" && aide_ok=0
grep -Fq 'eD+Jr7xjbH8fbRgwNs1lvk2rdR69LOE0' "${work}/excerpt.txt" && aide_ok=0
grep -Fq 'ligne(s) supplémentaire(s) non recopiées' "${work}/excerpt.txt" && aide_ok=0
if [[ "${aide_ok}" -eq 1 ]]; then
    t_pass "branch.usr.aide.paths" "chaque chemin AIDE est dans l'alerte"
else
    t_fail "branch.usr.aide.paths" "$(tr '\n' ' ' < "${work}/excerpt.txt")"
fi

for id in usr.collect.install usr.base usr.integrity.bin usr.integrity.list usr.integrity.stamp usr.behavior.bin usr.behavior.stamp usr.egress.bin usr.egress.stamp usr.egress.table usr.isolate.state usr.net.ufw usr.boot.order usr.boot.timer usr.boot.scan-timer usr.periodic.timer usr.hourly.timer usr.clamav.lock usr.clamav.deny usr.conf.order usr.conf.base; do
    if grep -q "${id}" "${probe}"; then
        t_pass "probe.id.${id}" "présent"
    else
        t_fail "probe.id.${id}" "absent de vm-probe.sh"
    fi
done
for unit in auditd clamav-daemon clamav-freshclam clamonacc fail2ban crowdsec; do
    if grep -q "for unit in auditd clamav-daemon clamav-freshclam clamonacc fail2ban crowdsec; do" "${probe}"; then
        t_pass "probe.id.usr.service.${unit}" "présent"
    else
        t_fail "probe.id.usr.service.${unit}" "boucle absente"
    fi
done
