#!/usr/bin/env bash
# =============================================================================
# File       : test/suites/09_watchdog_branches.sh
# Updated at : 2026-10-20
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Run each workstation watchdog branch in a sandbox.
# -----------------------------------------------------------------------------

hft_section "branches des contrôles poste"

holder_pid=""
work=""
bin=""
base=""
parent="$(cd -- "${HFT_ROOT}/.." && pwd)"
probe="${parent}/scripts/vm-probe.sh"

hft_stop_holder() {
    if [[ -n "${holder_pid}" ]]; then
        kill -TERM "${holder_pid}" 2>/dev/null || true
        wait "${holder_pid}" 2>/dev/null || true
        holder_pid=""
    fi
}

hft_link_tools() {
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

hft_prepare_user() {
    local name="$1"
    hft_stop_holder
    work="${HF_ARTIFACTS}/branch/${name}"
    rm -rf "${work}"
    base="${work}/base"
    bin="${base}/cron/bin"
    mkdir -p "${bin}" "${work}/path" "${work}/run" "${work}/samples" "${work}/bin" "${work}/quarantine"
    hft_link_tools "${work}/path"
    cp "${HFT_ROOT}/service/cron/watchdogs/common.sh" "${bin}/common.sh"
    cp "${HFT_ROOT}/service/cron/watchdogs/${name}" "${bin}/${name}"
    chmod 755 "${bin}/${name}"
    cat > "${bin}/watchdog.sh" << EOF
hf_log_alert() { printf '%s\n' "\$*" >> "${base}/alert.log"; }
hf_get_crash_sentence() { printf 'crash %s %s' "\$1" "\$2"; }
hf_arm_crash_mail() { :; }
hf_run_limited() { "\$@"; }
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

hft_write_runner() {
    local script="$1"
    local extra="${2:-}"
    cat > "${work}/run.sh" << EOF
#!/usr/bin/env bash
export PATH="${work}/path"
export HFU_BASE="${base}"
export HFU_CLAMAV_QUARANTINE_DIR="${work}/quarantine"
${extra}
set +e
/usr/bin/bash "${script}" > "${work}/stdout.txt" 2> "${work}/stderr.txt"
printf '%s\n' "\$?" > "${work}/status"
EOF
}

hft_box() {
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
        --setenv HFU_BASE "${base}"
    )
    if [[ -n "${proc_bind}" ]]; then
        args+=(--bind "${proc_bind}" /proc)
    else
        args+=(--proc /proc)
    fi
    bwrap "${args[@]}" /usr/bin/bash "${work}/run.sh"
}

hft_run_user() {
    local script="$1"
    local proc_bind="${2:-}"
    local extra="${3:-}"
    hft_write_runner "${script}" "${extra}"
    if ! hft_box "${proc_bind}"; then
        printf '%s\n' "bwrap" > "${work}/status"
    fi
}

hft_got_status() {
    cat "${work}/status" 2>/dev/null || printf '%s\n' "missing"
}

hft_stdout_has() {
    grep -F -q -- "$1" "${work}/stdout.txt" 2>/dev/null
}

hft_alert_has() {
    grep -F -q -- "$1" "${base}/alert.log" 2>/dev/null
}

hft_log_has() {
    grep -R -F -q -- "$1" "${base}/cron/security_logs" 2>/dev/null
}

hft_start_holder() {
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

hft_ausearch_stub() {
    local code="$1"
    local body="$2"
    cat > "${work}/path/ausearch" << EOF
#!/bin/bash
printf '%s\n' "${body}"
exit ${code}
EOF
    chmod 755 "${work}/path/ausearch"
}

hft_journal_stub() {
    local body="$1"
    cat > "${work}/path/journalctl" << EOF
#!/bin/bash
printf '%s\n' "${body}"
exit 0
EOF
    chmod 755 "${work}/path/journalctl"
}

if ! command -v bwrap >/dev/null 2>&1; then
    hft_fail "branch.bwrap" "bwrap absent"
else
    hft_pass "branch.bwrap" "bwrap présent"
fi

hft_prepare_user integrity.sh
hft_run_user "${bin}/integrity.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "liste d'intégrité absente" && [[ ! -e "${base}/alert.log" ]]; then
    hft_pass "branch.usr.integrity.missing" "liste absente, pas de courrier"
else
    hft_fail "branch.usr.integrity.missing" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user integrity.sh
printf 'alpha\n' > "${base}/file-a"
mkdir -p "${base}/src/config/integrity"
cat > "${base}/src/config/integrity/paths.list" << EOF
# comment
/no/such/high-fortress-file
${base}/file-a
EOF
hft_run_user "${bin}/integrity.sh"
stamp="${base}/cron/integrity.sha256"
mode="$(stat -c '%a' "${stamp}" 2>/dev/null || echo missing)"
lines="$(grep -c . "${stamp}" 2>/dev/null || echo 0)"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "empreinte initiale écrite" \
    && [[ "${mode}" == "600" ]] && [[ "${lines}" == "1" ]] && [[ ! -e "${base}/alert.log" ]]; then
    hft_pass "branch.usr.integrity.first" "empreinte initiale, mode 600"
    hft_pass "branch.usr.integrity.skip" "un seul fichier retenu"
else
    hft_fail "branch.usr.integrity.first" "statut $(hft_got_status) mode ${mode} lignes ${lines} $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
    hft_fail "branch.usr.integrity.skip" "lignes ${lines}"
fi
saved="$(mktemp)"
cp "${stamp}" "${saved}"
hft_run_user "${bin}/integrity.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "intégrité inchangée" && cmp -s "${saved}" "${stamp}" && [[ ! -e "${base}/alert.log" ]]; then
    hft_pass "branch.usr.integrity.same" "empreinte inchangée"
else
    hft_fail "branch.usr.integrity.same" "statut $(hft_got_status)"
fi
printf 'beta\n' > "${base}/file-a"
hft_run_user "${bin}/integrity.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_alert_has "intégrité : empreinte modifiée" && ! cmp -s "${saved}" "${stamp}"; then
    hft_pass "branch.usr.integrity.change" "courrier"
else
    hft_fail "branch.usr.integrity.change" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi
rm -f "${saved}"

hft_prepare_user behavior.sh
rm -f "${work}/path/ausearch"
hft_run_user "${bin}/behavior.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "ausearch absent" && [[ ! -e "${base}/cron/behavior.stamp" ]] && [[ ! -e "${base}/alert.log" ]]; then
    hft_pass "branch.usr.behavior.absent" "ausearch absent"
else
    hft_fail "branch.usr.behavior.absent" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user behavior.sh
printf '%s\n' 'nope' > "${base}/cron/behavior.stamp"
hft_ausearch_stub 0 "unused"
hft_run_user "${bin}/behavior.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "repère initial écrit" \
    && grep -Eq '^[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "${base}/cron/behavior.stamp" \
    && [[ "$(stat -c '%a' "${base}/cron/behavior.stamp")" == "600" ]]; then
    hft_pass "branch.usr.behavior.stamp" "repère réécrit"
else
    hft_fail "branch.usr.behavior.stamp" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user behavior.sh
printf '%s\n' '01/02/2026 03:04:05' > "${base}/cron/behavior.stamp"
cp "${base}/cron/behavior.stamp" "${work}/saved.stamp"
hft_ausearch_stub 1 "no match"
hft_run_user "${bin}/behavior.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "aucune exécution temporaire" \
    && ! cmp -s "${work}/saved.stamp" "${base}/cron/behavior.stamp" && [[ ! -e "${base}/alert.log" ]]; then
    hft_pass "branch.usr.behavior.clean" "silence et repère avancé"
else
    hft_fail "branch.usr.behavior.clean" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user behavior.sh
printf '%s\n' '01/02/2026 03:04:05' > "${base}/cron/behavior.stamp"
cp "${base}/cron/behavior.stamp" "${work}/saved.stamp"
hft_ausearch_stub 130 "boom"
hft_run_user "${bin}/behavior.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "aucune exécution temporaire" \
    && ! cmp -s "${work}/saved.stamp" "${base}/cron/behavior.stamp" && [[ ! -e "${base}/alert.log" ]]; then
    hft_pass "branch.usr.behavior.nonzero" "échec ausearch, pas de courrier"
else
    hft_fail "branch.usr.behavior.nonzero" "statut $(hft_got_status)"
fi

hft_prepare_user behavior.sh
printf '%s\n' '01/02/2026 03:04:05' > "${base}/cron/behavior.stamp"
hft_ausearch_stub 0 "type=EXECVE key=exec-tmp"
hft_run_user "${bin}/behavior.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_alert_has "exécution depuis un répertoire temporaire"; then
    hft_pass "branch.usr.behavior.hit" "courrier"
else
    hft_fail "branch.usr.behavior.hit" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user egress-watch.sh
rm -f "${work}/path/journalctl"
hft_run_user "${bin}/egress-watch.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "journalctl absent" && [[ ! -e "${base}/cron/egress.stamp" ]]; then
    hft_pass "branch.usr.egress.absent" "journalctl absent"
else
    hft_fail "branch.usr.egress.absent" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user egress-watch.sh
printf '%s\n' 'nope' > "${base}/cron/egress.stamp"
hft_journal_stub "unused"
hft_run_user "${bin}/egress-watch.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "repère initial écrit" \
    && grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "${base}/cron/egress.stamp"; then
    hft_pass "branch.usr.egress.stamp" "repère réécrit"
else
    hft_fail "branch.usr.egress.stamp" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
cp "${base}/cron/egress.stamp" "${work}/saved.stamp"
hft_journal_stub "kernel: nothing"
hft_run_user "${bin}/egress-watch.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_stdout_has "aucun flux sortant inattendu" \
    && ! cmp -s "${work}/saved.stamp" "${base}/cron/egress.stamp" && [[ ! -e "${base}/alert.log" ]]; then
    hft_pass "branch.usr.egress.clean" "silence et repère avancé"
else
    hft_fail "branch.usr.egress.clean" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user egress-watch.sh
printf '%s\n' '2026-01-02 03:04:05' > "${base}/cron/egress.stamp"
hft_journal_stub "hfu-egress OUT=eth0"
hft_run_user "${bin}/egress-watch.sh"
if [[ "$(hft_got_status)" == "0" ]] && hft_alert_has "flux sortants hors des ports 53, 80 et 443"; then
    hft_pass "branch.usr.egress.hit" "courrier"
else
    hft_fail "branch.usr.egress.hit" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user boot-scan.sh
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
hft_run_user "${bin}/boot-scan.sh"
expected="$(printf '%s\n' "${order_names[@]}")"
if [[ "$(hft_got_status)" == "0" ]] && [[ "$(cat "${work}/trace" 2>/dev/null || true)" == "${expected}" ]]; then
    hft_pass "branch.usr.boot.order" "neuf contrôles"
else
    hft_fail "branch.usr.boot.order" "$(tr '\n' ' ' < "${work}/trace" 2>/dev/null || true) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi
if hft_alert_has "crash rkhunter 1"; then
    hft_pass "branch.usr.boot.continue" "échec puis suite"
else
    hft_fail "branch.usr.boot.continue" "courrier absent"
fi

hft_prepare_user clamav-event.sh
sample="${work}/samples/.clamav-quarantine-lock.1"
printf 'lock\n' > "${sample}"
hft_run_user "${bin}/clamav-event.sh" "" "export CLAM_VIRUSEVENT_FILENAME=${sample}
export CLAM_VIRUSEVENT_VIRUSNAME=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && [[ ! -e "${base}/alert.log" ]] && ! hft_log_has "quarantaine"; then
    hft_pass "branch.usr.clamav.lock" "verrou avant la réponse"
else
    hft_fail "branch.usr.clamav.lock" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
: > "${work}/holder.pid"
hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "déplacé en quarantaine" \
    && [[ -n "$(find "${work}/quarantine" -type f -print)" ]] \
    && grep -q 'hfu_isolate' "${work}/nft.log" && grep -q 'dport 53' "${work}/nft.log" \
    && grep -q 'reject' "${work}/nft.log" && grep -q -- '--on-active=120' "${work}/systemd-run.log"; then
    hft_pass "branch.usr.response.move" "fichier en quarantaine"
    hft_pass "branch.usr.response.nft" "isolation 120"
else
    hft_fail "branch.usr.response.move" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
    hft_fail "branch.usr.response.nft" "$(tr '\n' ' ' < "${work}/nft.log" 2>/dev/null || true)"
fi

hft_prepare_user clamav-response.sh
hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${work}/samples/missing.txt
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "fichier déjà absent"; then
    hft_pass "branch.usr.response.absent" "fichier déjà absent"
else
    hft_fail "branch.usr.response.absent" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
printf '1\n' > "${work}/holder.pid"
hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "pid 1"; then
    hft_pass "branch.usr.response.pid1" "pid 1 conservé"
else
    hft_fail "branch.usr.response.pid1" "statut $(hft_got_status)"
fi

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
printf '42424242\n' > "${work}/holder.pid"
hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "uid 0"; then
    hft_pass "branch.usr.response.uid" "uid 0 conservé"
else
    hft_fail "branch.usr.response.uid" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
mkdir -p "${work}/fakeproc/42424242"
: > "${work}/fakeproc/42424242/comm"
printf '42424242\n' > "${work}/holder.pid"
hft_run_user "${bin}/clamav-response.sh" "${work}/fakeproc" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "nom absent"; then
    hft_pass "branch.usr.response.empty" "nom vide conservé"
else
    hft_fail "branch.usr.response.empty" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
hft_start_holder gamescope
hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "non arrêté : gamescope" && kill -0 "${holder_pid}" 2>/dev/null; then
    hft_pass "branch.usr.response.deny" "gamescope conservé"
else
    hft_fail "branch.usr.response.deny" "statut $(hft_got_status) $(grep -R -F -h 'processus' "${base}/cron/security_logs" 2>/dev/null | tr '\n' ' ')"
fi
hft_stop_holder

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
hft_start_holder worker
hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has ") arrêté" && ! kill -0 "${holder_pid}" 2>/dev/null; then
    hft_pass "branch.usr.response.term" "TERM envoyé"
else
    hft_fail "branch.usr.response.term" "statut $(hft_got_status) $(grep -R -F -h 'processus' "${base}/cron/security_logs" 2>/dev/null | tr '\n' ' ')"
fi
hft_stop_holder

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
mkdir -p "${work}/fakeproc/42424242"
printf '%s' 'worker' > "${work}/fakeproc/42424242/comm"
printf '42424242\n' > "${work}/holder.pid"
hft_run_user "${bin}/clamav-response.sh" "${work}/fakeproc" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "signal refusé"; then
    hft_pass "branch.usr.response.refused" "signal refusé"
else
    hft_fail "branch.usr.response.refused" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_prepare_user clamav-response.sh
sample="${work}/samples/note.txt"
printf 'note\n' > "${sample}"
rm -f "${work}/path/nft"
hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${sample}
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "nft absent" && [[ ! -e "${work}/nft.log" ]]; then
    hft_pass "branch.usr.response.nft-absent" "nft absent"
else
    hft_fail "branch.usr.response.nft-absent" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/stderr.txt" 2>/dev/null || true)"
fi

hft_check_user_sec() {
    local id="$1"
    local raw="$2"
    local expect="$3"
    hft_prepare_user clamav-response.sh
    printf 'note\n' > "${work}/samples/note.txt"
    printf 'HFU_NET_ISOLATE_SEC=%s\n' "${raw}" > "${base}/cron/egress.conf"
    hft_run_user "${bin}/clamav-response.sh" "" "export HFU_CLAMAV_EVENT_FILE=${work}/samples/note.txt
export HFU_CLAMAV_EVENT_VIRUS=Eicar"
    if [[ "$(hft_got_status)" == "0" ]] && hft_log_has "isolation ${expect}s" \
        && grep -q -- "--on-active=${expect}" "${work}/systemd-run.log"; then
        hft_pass "${id}" "durée ${expect}"
    else
        hft_fail "${id}" "statut $(hft_got_status) $(tr '\n' ' ' < "${work}/systemd-run.log" 2>/dev/null || true)"
    fi
}
hft_check_user_sec branch.usr.response.clamp-low 10 120
hft_check_user_sec branch.usr.response.clamp-high 400 120
hft_check_user_sec branch.usr.response.sec 45 45

hft_stop_holder

for id in usr.collect.install usr.base usr.integrity.bin usr.integrity.list usr.integrity.stamp usr.behavior.bin usr.behavior.stamp usr.egress.bin usr.egress.stamp usr.egress.table usr.isolate.state usr.net.ufw usr.boot.order usr.boot.timer usr.boot.scan-timer usr.periodic.timer usr.hourly.timer usr.clamav.lock usr.clamav.deny usr.conf.order usr.conf.base; do
    if grep -q "${id}" "${probe}"; then
        hft_pass "probe.id.${id}" "présent"
    else
        hft_fail "probe.id.${id}" "absent de vm-probe.sh"
    fi
done
for unit in auditd clamav-daemon clamav-freshclam clamonacc fail2ban crowdsec; do
    if grep -q "for unit in auditd clamav-daemon clamav-freshclam clamonacc fail2ban crowdsec; do" "${probe}"; then
        hft_pass "probe.id.usr.service.${unit}" "présent"
    else
        hft_fail "probe.id.usr.service.${unit}" "boucle absente"
    fi
done
