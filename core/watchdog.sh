#!/usr/bin/env bash
# =============================================================================
# File       : core/watchdog.sh
# Updated at : 2026-10-26
# Creator    : palarchsys
# =============================================================================

hf_get_product_base() {
    if [[ -n "${HFU_BASE:-}" ]]; then
        printf '%s' "${HFU_BASE}"
    elif [[ -n "${HF_CONFIG_BASE_DIRECTORY:-}" ]]; then
        printf '%s' "${HF_CONFIG_BASE_DIRECTORY}"
    elif [[ -n "${HF_BASE:-}" ]]; then
        printf '%s' "${HF_BASE}"
    else
        printf '%s' "/opt/high-fortress"
    fi
}

hf_send_path() {
    if [[ -n "${CRON_BIN_PATH:-}" && -x "${CRON_BIN_PATH}/send.sh" ]]; then
        printf '%s\n' "${CRON_BIN_PATH}/send.sh"
        return 0
    fi
    local base
    base="$(hf_get_product_base)"
    if [[ -x "${base}/cron/bin/send.sh" ]]; then
        printf '%s\n' "${base}/cron/bin/send.sh"
        return 0
    fi
    return 1
}

hf_signal_phrase() {
    case "$1" in
        6) printf '%s' 'abandon du programme' ;;
        7) printf '%s' 'accès mémoire invalide' ;;
        9) printf '%s' 'arrêt forcé' ;;
        11) printf '%s' 'erreur interne du programme' ;;
        13) printf '%s' 'écriture interrompue' ;;
        15) printf '%s' "demande d'arrêt" ;;
        *) printf 'signal %s' "$1" ;;
    esac
}

hf_get_crash_sentence() {
    local label="$1"
    local status="$2"
    local signal phrase journal
    if [[ "${status}" -ge 128 ]]; then
        signal=$((status - 128))
        phrase="$(hf_signal_phrase "${signal}")"
        printf "Le contrôle %s a planté (signal %s, %s). Il n'est pas allé au bout." "${label}" "${signal}" "${phrase}"
    else
        printf "Le contrôle %s s'est arrêté (code %s). Il n'est pas allé au bout." "${label}" "${status}"
    fi
    journal="${LOG_FILE:-${LOG:-}}"
    if [[ -n "${journal}" ]]; then
        printf ' Le journal est %s.' "${journal}"
    fi
    printf '\n'
}

hf_send_crash_mail() {
    local status=$?
    if [[ -n "${1-}" ]]; then
        status="$1"
    fi
    trap - EXIT
    [[ "${status}" -eq 0 ]] && return 0
    hf_log_alert "$(hf_get_crash_sentence "${HF_CRASH_LABEL:-${HFU_CRASH_LABEL:-contrôle}}" "${status}")" || true
}

hf_arm_crash_mail() {
    HF_CRASH_LABEL="$1"
    HFU_CRASH_LABEL="$1"
    trap hf_send_crash_mail EXIT
}

hf_get_cpu_quota_percent() {
    local limit="${HF_WATCHDOG_CPU_LIMIT:-50}"
    local n=1
    if [[ ! "${limit}" =~ ^[0-9]+$ ]]; then
        limit=50
    fi
    if command -v nproc >/dev/null 2>&1; then
        n="$(nproc 2>/dev/null)" || n=1
    fi
    if [[ ! "${n}" =~ ^[0-9]+$ ]] || [[ "${n}" -lt 1 ]]; then
        n=1
    fi
    printf '%s\n' "$((limit * n))"
}

hf_run_limited() {
    local status=0 pid=0 lim=0 errexit=0
    local -a cmd=()
    case $- in
        *e*) errexit=1 ;;
    esac
    set +e
    if [[ "${HF_LIMIT_WRAP:-1}" == "0" ]]; then
        "$@"
        status=$?
    else
        if command -v nice >/dev/null 2>&1; then
            cmd+=(nice -n "${HF_WATCHDOG_LIMIT_NICE:-19}")
        fi
        if command -v ionice >/dev/null 2>&1; then
            cmd+=(ionice -c "${HF_WATCHDOG_LIMIT_IO_NICE:-3}")
        fi
        if [[ "${#cmd[@]}" -eq 0 ]]; then
            "$@" &
        else
            "${cmd[@]}" "$@" &
        fi
        pid=$!
        if command -v cpulimit >/dev/null 2>&1; then
            cpulimit -p "${pid}" -l "$(hf_get_cpu_quota_percent)" -z >/dev/null 2>&1 &
            lim=$!
        fi
        wait "${pid}"
        status=$?
        if [[ "${lim}" -ne 0 ]]; then
            kill "${lim}" 2>/dev/null
            wait "${lim}" 2>/dev/null
        fi
    fi
    if [[ "${errexit}" -eq 1 ]]; then
        set -e
    fi
    return "${status}"
}

hf_get_alert_excerpt() {
    python3 - "${1:-}" << 'PY'
import re
import sys
from pathlib import Path

path = sys.argv[1]
raw = ""
if path and Path(path).is_file():
    raw = Path(path).read_text(errors="replace")

def redact(text):
    text = re.sub(
        r"(?is)-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----",
        "[clé privée masquée]",
        text,
    )
    text = re.sub(
        r"(?i)\b(password|passwd|token|secret|api[_-]?key|authorization|bearer)\b(\s*[:=]\s*)\S+",
        r"\1\2[masqué]",
        text,
    )
    text = re.sub(r"(?i)\bbearer\s+[A-Za-z0-9._~+/-]{8,}", "Bearer [masqué]", text)
    return text

def clip(lines, limit=120):
    if len(lines) <= limit:
        return lines
    hidden = len(lines) - limit
    return lines[:limit] + [f"... {hidden} ligne(s) supplémentaire(s) non recopiées"]

def format_aide(text):
    kept = []
    interesting = re.compile(
        r"^(summary:|total number|added entries|removed entries|changed entries|"
        r"aide found|start timestamp|end timestamp|f[+-]{3,}:|file:)",
        re.I,
    )
    attr = re.compile(r"^\s{2,}(Size|Perm|Mtime|Ctime|Inode|Linkcount|UID|GID)\s*:", re.I)
    for line in text.splitlines():
        if interesting.search(line.strip()) or interesting.match(line) or attr.match(line):
            kept.append(line.rstrip())
        elif re.match(r"^\s*(added|removed|changed) entries:\s*$", line, re.I):
            kept.append(line.rstrip())
    return clip(kept)

def format_named(name, text):
    low = name.lower()
    lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
    if "aide" in low:
        picked = format_aide(text)
        return picked or clip(lines)
    if "rkhunter" in low:
        picked = []
        keep = False
        for raw in text.splitlines():
            line = raw.rstrip()
            stripped = line.strip()
            if not stripped:
                keep = False
                continue
            if re.search(r"Rootkit Hunter version", line, re.I):
                keep = False
                continue
            if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T", stripped):
                keep = False
                continue
            if re.search(r"warning|infected|rootkit|suspect|quarantaine", line, re.I):
                keep = True
                picked.append(line)
                continue
            if keep and (line[:1] in (" ", "\t") or stripped.startswith("/")):
                picked.append(line)
                continue
            keep = False
        return clip(picked)
    if "clam" in low:
        picked = []
        for raw in text.splitlines():
            line = raw.rstrip()
            stripped = line.strip()
            if not stripped:
                continue
            if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T", stripped):
                continue
            if re.search(
                r"Known viruses:|Infected files:|Engine version:|Scanned directories:|"
                r"Scanned files:|Data scanned:|Data read:|Time:|Start Date:|End Date:",
                line,
            ):
                continue
            if re.search(
                r"Access denied|Can't access|Can't open file|Permission denied|No such file",
                line,
                re.I,
            ):
                continue
            if "planté signal" in line or "contrôle arrêté" in line:
                picked.append(line)
                continue
            if stripped.endswith(" FOUND") or re.search(
                r"Signature|Fichier|Emplacement|Quarantaine", line
            ):
                picked.append(line)
                continue
            if re.search(r"ERROR:|LibClamAV", line):
                picked.append(line)
        return clip(picked)
    return clip(lines)

name = Path(path).name if path else ""
body = format_named(name, redact(raw))
if body:
    sys.stdout.write("\n".join(body))
PY
}

hf_get_clamav_kind() {
    python3 - "${1:-}" << 'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] else None
text = path.read_text(errors="replace") if path and path.is_file() else ""
if re.search(r" FOUND$", text, re.M):
    sys.stdout.write("infected")
    raise SystemExit(0)
access = re.compile(
    r"Access denied|Can't access|Can't open file|Permission denied|No such file",
    re.I,
)
summary = re.compile(
    r"Known viruses:|Infected files:|Engine version:|Scanned directories:|"
    r"Scanned files:|Data scanned:|Data read:|^Time:|Start Date:|End Date:"
)
real = False
for raw in text.splitlines():
    line = raw.strip()
    if not line or summary.search(line) or access.search(line):
        continue
    if line.startswith("-----------") or re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T", line):
        continue
    if re.search(r"ERROR:|LibClamAV", line):
        real = True
if real:
    sys.stdout.write("error")
else:
    sys.stdout.write("ok")
PY
}

hf_invoke_clamav() {
    if [[ "${HF_CLAM_MODE:-scan}" == "daemon" ]]; then
        hf_run_limited clamdscan --fdpass --infected --no-summary -- "$@"
    else
        clamscan --infected --no-summary -- "$@"
    fi
}

hf_scan_clamav_batch() {
    local status=0 signal=0 streak=0 path errexit=0 tool="clamscan"
    [[ "$#" -gt 0 ]] || return 0
    if [[ "${HF_CLAM_MODE:-scan}" == "daemon" ]]; then
        tool="clamdscan"
    fi
    case $- in
        *e*) errexit=1 ;;
    esac
    set +e
    hf_invoke_clamav "$@"
    status=$?
    if [[ "${errexit}" -eq 1 ]]; then
        set -e
    fi
    if [[ "${status}" -lt 128 ]]; then
        return 0
    fi
    streak=0
    for path in "$@"; do
        set +e
        hf_invoke_clamav "${path}"
        status=$?
        if [[ "${errexit}" -eq 1 ]]; then
            set -e
        fi
        if [[ "${status}" -ge 128 ]]; then
            signal=$((status - 128))
            printf '%s planté signal %s sur %s\n' "${tool}" "${signal}" "${path}"
            streak=$((streak + 1))
            if [[ "${streak}" -ge 2 ]]; then
                printf '%s planté signal %s, contrôle arrêté\n' "${tool}" "${signal}"
                HF_CLAM_STOP=1
                HFU_CLAMAV_STOP=1
                return 0
            fi
        else
            streak=0
        fi
    done
    return 0
}

hf_list_clamav_scan() {
    local file_list="$1"
    local path batch_max
    local -a batch=()
    batch_max="${HF_CLAM_BATCH:-80}"
    HF_CLAM_STOP=0
    HFU_CLAMAV_STOP=0
    while IFS= read -r -d '' path || [[ -n "${path}" ]]; do
        [[ -n "${path}" ]] || continue
        batch+=("${path}")
        if [[ "${#batch[@]}" -eq "${batch_max}" ]]; then
            hf_scan_clamav_batch "${batch[@]}" || true
            batch=()
            [[ "${HF_CLAM_STOP}" == 1 ]] && break
        fi
    done < "${file_list}"
    if [[ "${#batch[@]}" -gt 0 && "${HF_CLAM_STOP}" != 1 ]]; then
        hf_scan_clamav_batch "${batch[@]}" || true
    fi
    return 0
}

hf_prepare_rkhunter_note() {
    local base
    base="$(hf_get_product_base)"
    NOTE="Si ce journal correspond à des changements attendus (une mise à jour, un logiciel que vous avez installé, un fichier que vous avez modifié) et qu'il ne révèle pas d'anomalie, exécutez la commande ci-dessous. Elle recalcule la base de propriétés rkhunter à partir du disque actuel."
    NOTE_CMD="sudo bash ${base}/bin/rkhunter-refresh-db.sh"
}

hf_repair_debsums_log() {
    local log="$1"
    local summary=""
    [[ -n "${log}" && -s "${log}" ]] || return 0
    summary="$(
        python3 - "${log}" << 'PY' || true
import hashlib
import io
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

log_path = Path(sys.argv[1])
name_re = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.+-]*(?::[A-Za-z0-9]+)?$")
pkg_re = re.compile(
    r"\(from ([A-Za-z0-9][A-Za-z0-9.+-]*(?::[A-Za-z0-9]+)?) package\)\s*$"
)
path_re = re.compile(r"^debsums: changed file (.+?) \(from ")

def package_of(path):
    try:
        out = subprocess.check_output(
            ["dpkg", "-S", path], text=True, stderr=subprocess.DEVNULL
        )
    except (subprocess.CalledProcessError, OSError):
        return ""
    token = out.split(":", 1)[0].split(",")[0].strip()
    return token if name_re.match(token) else ""

packages = []
seen = set()
leftover = []
for raw in log_path.read_text(errors="replace").splitlines():
    line = raw.strip()
    if not line:
        continue
    named = pkg_re.search(line)
    if named and named.group(1) not in seen:
        seen.add(named.group(1))
        packages.append(named.group(1))
        continue
    found = path_re.match(line)
    path = found.group(1).strip() if found else (line if line.startswith("/") else "")
    pkg = package_of(path) if path else ""
    if pkg and pkg not in seen:
        seen.add(pkg)
        packages.append(pkg)
        continue
    if line not in leftover:
        leftover.append(line)

def run(cmd):
    env = os.environ.copy()
    env["DEBIAN_FRONTEND"] = "noninteractive"
    env["NEEDRESTART_MODE"] = "l"
    env["APT_LISTCHANGES_FRONTEND"] = "none"
    return subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)

cache_dir = None

def purge_cache():
    # Une différence ne repasse pas par le cache apt. Il est purgé avant le téléchargement.
    run(["apt-get", "clean"])
    for root in (Path("/var/cache/apt/archives"), Path("/var/cache/apt/archives/partial")):
        if not root.is_dir():
            continue
        try:
            entries = list(root.iterdir())
        except OSError:
            continue
        for path in entries:
            if path.is_file() and ".deb" in path.name:
                try:
                    path.unlink()
                except OSError:
                    pass

def private_cache():
    global cache_dir
    if cache_dir is None:
        cache_dir = Path(tempfile.mkdtemp(prefix="hf-apt-"))
        (cache_dir / "partial").mkdir()
    return cache_dir

def reinstall(pkg):
    archives = private_cache()
    return run([
        "apt-get", "-o", f"Dir::Cache::archives={archives}/",
        "install", "--reinstall", "-y", "--", pkg,
    ])

def fresh_debs(pkg):
    if cache_dir is None or not cache_dir.is_dir():
        return []
    prefix = pkg.split(":", 1)[0] + "_"
    found = []
    try:
        entries = list(cache_dir.iterdir())
    except OSError:
        return []
    for path in entries:
        if path.is_file() and path.suffix == ".deb" and path.name.startswith(prefix):
            found.append(path)
    return found

def sums_ok(check):
    return check.returncode == 0 and not check.stdout.strip()

def failing_paths(text):
    found = []
    pattern = re.compile(r"(?:changed|missing) file (\S+)")
    for raw in text.splitlines():
        line = raw.strip()
        named = pattern.search(line)
        if named:
            found.append(named.group(1))
        elif line.startswith("/"):
            found.append(line.split()[0])
    return found

def archive_member(deb, rel):
    proc = subprocess.run(
        ["dpkg-deb", "--fsys-tarfile", str(deb)],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if proc.returncode != 0:
        return None
    want = rel.lstrip("/")
    try:
        tf = tarfile.open(fileobj=io.BytesIO(proc.stdout), mode="r|*")
    except tarfile.TarError:
        return None
    while True:
        try:
            member = tf.next()
        except tarfile.TarError:
            return None
        if member is None:
            return None
        if member.name.lstrip("./") != want:
            continue
        if member.issym() or member.islnk():
            return ("link", member.linkname)
        if member.isfile():
            extracted = tf.extractfile(member)
            return ("file", extracted.read() if extracted else b"")
        return None

def disk_matches_archive(deb, path):
    member = archive_member(deb, path)
    disk = Path(path)
    if member is None:
        return not disk.exists()
    kind, payload = member
    if kind == "link":
        return disk.is_symlink() and os.readlink(disk) == payload
    if disk.is_symlink() or not disk.is_file():
        return False
    return hashlib.md5(disk.read_bytes()).hexdigest() == hashlib.md5(payload).hexdigest()

def archive_explains(pkg, text):
    try:
        paths = failing_paths(text)
        debs = fresh_debs(pkg)
        if not paths or not debs:
            return False
        deb = max(debs, key=lambda path: path.stat().st_mtime)
        return all(disk_matches_archive(deb, path) for path in paths)
    except OSError:
        return False

blocks = []
restored = []
failed = []
try:
    if packages:
        purge_cache()
    for pkg in packages:
        apt = reinstall(pkg)
        if apt.returncode != 0:
            failed.append(pkg)
            err = next((ln.strip() for ln in reversed(apt.stdout.splitlines()) if ln.strip()), "apt-get a échoué")
            blocks.extend([f"{pkg} : réinstallation échouée.", err, ""])
            continue
        check = run(["debsums", "-s", pkg])
        if sums_ok(check):
            restored.append(pkg)
            blocks.extend([f"{pkg} réinstallé.", "La somme correspond.", ""])
        elif archive_explains(pkg, check.stdout):
            continue
        else:
            failed.append(pkg)
            detail = [
                ln.strip()
                for ln in check.stdout.splitlines()
                if ln.strip() and (" file " in ln or ln.strip().startswith("/"))
            ]
            blocks.extend([f"{pkg} réinstallé.", "La somme reste différente.", *detail, ""])
    for line in leftover:
        failed.append(line)
        blocks.extend([line, ""])

    report = "\n".join(blocks).rstrip()
    log_path.write_text((report + "\n") if report else "")
    if restored and not failed:
        if len(restored) == 1:
            sys.stdout.write(f"debsums : {restored[0]} réinstallé, somme rétablie")
        else:
            sys.stdout.write(f"debsums : {len(restored)} paquets réinstallés, sommes rétablies")
    elif restored or failed:
        sys.stdout.write("debsums : correction incomplète")
finally:
    if cache_dir is not None:
        shutil.rmtree(cache_dir, ignore_errors=True)
PY
    )"
    printf '%s' "${summary}"
}

hf_record_quarantine_origin() {
    local source="$1"
    local origin="$2"
    local stored="$3"
    local signature="${4:-}"
    local base dir registry id moment quoted
    [[ -n "${stored}" && "${stored}" != "absent" && "${stored}" != "inconnue" ]] || return 0
    [[ "${origin}" == /* && "${origin}" != "${stored}" ]] || return 0
    id="$(basename -- "${stored}")"
    [[ "${id}" =~ ^[0-9]{8}-[0-9]{6}-[0-9]+- ]] || return 0
    base="$(hf_get_product_base)"
    dir="${base}/cron"
    registry="${dir}/quarantine.registry"
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}" 2>/dev/null || return 0
    fi
    [[ -w "${dir}" ]] || return 0
    source="${source//$'\t'/ }"
    origin="${origin//$'\t'/ }"
    stored="${stored//$'\t'/ }"
    signature="${signature//$'\t'/ }"
    signature="${signature//$'\n'/ }"
    moment="$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${id}" "${moment}" "${source}" "${origin}" "${stored}" "${signature}" \
        >> "${registry}" || return 0
    chmod 600 "${registry}" 2>/dev/null || true
    quoted="$(printf '%q' "${id}")"
    printf '%s\n' "sudo bash ${base}/bin/quarantine-restore.sh ${quoted}" >> "${dir}/quarantine.pending" || return 0
    chmod 600 "${dir}/quarantine.pending" 2>/dev/null || true
    return 0
}

hf_queue_existing_restore() {
    local stored="$1"
    local base registry id quoted
    [[ -n "${stored}" && "${stored}" == /* ]] || return 0
    base="$(hf_get_product_base)"
    registry="${base}/cron/quarantine.registry"
    [[ -f "${registry}" && -r "${registry}" ]] || return 0
    id="$(awk -F '\t' -v want="${stored}" '$5 == want { print $1; exit }' "${registry}" 2>/dev/null || true)"
    [[ -n "${id}" ]] || return 0
    [[ -w "${base}/cron" ]] || return 0
    quoted="$(printf '%q' "${id}")"
    printf '%s\n' "sudo bash ${base}/bin/quarantine-restore.sh ${quoted}" >> "${base}/cron/quarantine.pending" || return 0
    chmod 600 "${base}/cron/quarantine.pending" 2>/dev/null || true
    return 0
}

hf_take_quarantine_note() {
    local pending body
    pending="$(hf_get_product_base)/cron/quarantine.pending"
    [[ -s "${pending}" ]] || return 1
    body="$(cat "${pending}" 2>/dev/null || true)"
    [[ -n "${body}" ]] || return 1
    NOTE="Pour remettre chaque fichier à son emplacement d'origine, copiez la commande correspondante."
    NOTE_CMD="${body}"
    rm -f "${pending}" 2>/dev/null || true
    return 0
}

hf_read_quarantine_holder() {
    local target="$1"
    local pid=""
    if command -v lsof >/dev/null 2>&1; then
        pid="$(lsof -t -- "${target}" 2>/dev/null | head -n 1 || true)"
    fi
    if [[ -z "${pid}" ]] && command -v fuser >/dev/null 2>&1; then
        pid="$(fuser -- "${target}" 2>/dev/null | awk '{print $1; exit}' || true)"
    fi
    printf '%s\n' "${pid}"
}

hf_quarantine_holder_block() {
    local target="$1"
    shift
    local pid="" comm="" uid="" name=""
    HF_QUARANTINE_PID=""
    HF_QUARANTINE_COMM=""
    pid="$(hf_read_quarantine_holder "${target}")"
    [[ -n "${pid}" && "${pid}" =~ ^[0-9]+$ ]] || return 1
    if [[ "${pid}" == "1" ]]; then
        printf '%s\n' "pid 1"
        return 0
    fi
    uid="$(stat -c '%u' "/proc/${pid}" 2>/dev/null || true)"
    if [[ -z "${uid}" || "${uid}" == "0" ]]; then
        printf '%s\n' "uid 0"
        return 0
    fi
    comm="$(cat "/proc/${pid}/comm" 2>/dev/null || true)"
    if [[ -z "${comm}" ]]; then
        printf '%s\n' "nom absent"
        return 0
    fi
    for name in "$@"; do
        if [[ "${comm}" == "${name}" || "${comm}" == "${name}"* ]]; then
            printf '%s\n' "${comm}"
            return 0
        fi
    done
    HF_QUARANTINE_PID="${pid}"
    HF_QUARANTINE_COMM="${comm}"
    return 1
}

hf_move_quarantine_file() {
    local origin="$1"
    local quarantine base stamp dest
    quarantine="${HFU_CLAMAV_QUARANTINE_DIR:-/var/lib/clamav/quarantine}"
    HF_MOVE_ACTION="déplacement refusé"
    HF_MOVE_STORED="${origin}"
    base="$(basename -- "${origin}")"
    [[ -n "${base}" && "${base}" != "/" && "${base}" != "." ]] || base="inconnu"
    if [[ ! -d "${quarantine}" ]]; then
        if id clamav >/dev/null 2>&1; then
            install -d -m 750 -o clamav -g clamav "${quarantine}" 2>/dev/null || true
        else
            install -d -m 750 "${quarantine}" 2>/dev/null || true
        fi
    fi
    if [[ ! -d "${quarantine}" || ! -w "${quarantine}" ]]; then
        return 0
    fi
    if [[ ! -e "${origin}" ]]; then
        HF_MOVE_ACTION="fichier déjà absent"
        HF_MOVE_STORED="absent"
        return 0
    fi
    if [[ ! -f "${origin}" || -L "${origin}" ]]; then
        return 0
    fi
    stamp="$(date +%Y%m%d-%H%M%S-%N)"
    dest="${quarantine}/${stamp}-${base}"
    if mv -- "${origin}" "${dest}"; then
        HF_MOVE_ACTION="déplacé en quarantaine"
        HF_MOVE_STORED="${dest}"
    else
        HF_MOVE_STORED="${origin}"
    fi
    return 0
}

hf_signal_quarantine_holder() {
    local origin="$1"
    local stored="$2"
    shift 2
    local target pid comm reason
    for target in "${origin}" "${stored}"; do
        [[ -n "${target}" && "${target}" != "absent" && -e "${target}" ]] || continue
        if reason="$(hf_quarantine_holder_block "${target}" "$@")"; then
            printf '%s\n' "processus non arrêté : ${reason}"
            return 0
        fi
        pid="${HF_QUARANTINE_PID:-}"
        comm="${HF_QUARANTINE_COMM:-}"
        [[ -n "${pid}" ]] || continue
        if kill -TERM "${pid}" 2>/dev/null; then
            printf '%s\n' "processus ${pid} (${comm}) arrêté"
        else
            printf '%s\n' "processus ${pid} non arrêté : signal refusé"
        fi
        return 0
    done
    printf '%s\n' "processus non arrêté : aucun détenteur"
}

hf_quarantine_confirmed_log() {
    local source="$1"
    local log="$2"
    shift 2
    local path reason phrase quarantine
    HF_CONFIRMED_COUNT=0
    HF_MOVED_COUNT=0
    [[ -n "${log}" && -f "${log}" ]] || return 0
    quarantine="${HFU_CLAMAV_QUARANTINE_DIR:-/var/lib/clamav/quarantine}"
    while IFS= read -r path; do
        [[ -n "${path}" ]] || continue
        case "${path}" in
            "${quarantine}"|"${quarantine}"/*) continue ;;
        esac
        [[ -f "${path}" && ! -L "${path}" ]] || continue
        HF_CONFIRMED_COUNT=$((HF_CONFIRMED_COUNT + 1))
        case "${path}" in
            /etc/passwd|/etc/shadow|/etc/sudoers|/etc/ssh/sshd_config|/etc/ufw/ufw.conf|/usr/bin/sudo|/usr/bin/passwd|/usr/sbin/sshd)
                printf '%s\n' "non mis en quarantaine : ${path}"
                continue
                ;;
        esac
        if reason="$(hf_quarantine_holder_block "${path}" "$@")"; then
            printf '%s\n' "non mis en quarantaine : ${reason}"
            continue
        fi
        hf_move_quarantine_file "${path}"
        if [[ "${HF_MOVE_ACTION}" != "déplacé en quarantaine" ]]; then
            printf '%s\n' "${HF_MOVE_ACTION} : ${path}"
            continue
        fi
        hf_record_quarantine_origin "${source}" "${path}" "${HF_MOVE_STORED}" "${source}" || true
        phrase="$(hf_signal_quarantine_holder "${path}" "${HF_MOVE_STORED}" "$@")"
        printf '%s\n' "déplacé en quarantaine : ${path} ; ${phrase} ; quarantaine ${HF_MOVE_STORED}"
        HF_MOVED_COUNT=$((HF_MOVED_COUNT + 1))
    done < <(python3 - "${source}" "${log}" << 'PY'
import re
import sys
from pathlib import Path

source = sys.argv[1]
log_path = Path(sys.argv[2])
text = log_path.read_text(errors="replace") if log_path.is_file() else ""
path_re = re.compile(r"(/[^\s<>|,;]+)")
seen = []
for raw in text.splitlines():
    line = raw.rstrip()
    if source == "rkhunter":
        if "Rootkit Hunter" in line:
            hit = "INFECTED" in line
        else:
            hit = ("INFECTED" in line) or ("Rootkit" in line)
    else:
        hit = "INFECTED" in line
    if not hit:
        continue
    for match in path_re.findall(line):
        path = match.rstrip(".,:)")
        if path not in seen:
            seen.append(path)
if seen:
    sys.stdout.write("\n".join(seen) + "\n")
PY
    )
    return 0
}

hf_format_egress_body() {
    local kernel="$1"
    local audit="${2:-}"
    HF_EGRESS_AUDIT_FILE="${audit}" python3 - "${kernel}" << 'PY'
import os
import re
import sys
from pathlib import Path

kernel_path = Path(sys.argv[1])
audit_path = os.environ.get("HF_EGRESS_AUDIT_FILE", "")
kernel_lines = []
seen = set()
if kernel_path.is_file():
    for raw in kernel_path.read_text(errors="replace").splitlines():
        line = raw.rstrip("\n")
        if not line.strip() or line in seen:
            continue
        seen.add(line)
        kernel_lines.append(line)

audit_text = ""
if audit_path and Path(audit_path).is_file():
    audit_text = Path(audit_path).read_text(errors="replace")

def parse_sockaddr(token):
    token = token.strip().strip('"')
    if token.lower().startswith("saddr="):
        token = token.split("=", 1)[1]
    host = re.search(r"host:([0-9A-Fa-f:.]+)", token)
    serv = re.search(r"serv:([0-9]+)", token)
    if host and serv:
        return host.group(1), serv.group(1)
    if not re.fullmatch(r"[0-9A-Fa-f]+", token) or len(token) < 16 or len(token) % 2:
        return None
    raw = bytes.fromhex(token)
    if len(raw) < 8:
        return None
    family = int.from_bytes(raw[0:2], "little")
    port = str(int.from_bytes(raw[2:4], "big"))
    if family == 2 and len(raw) >= 8:
        ip = ".".join(str(b) for b in raw[4:8])
        return ip, port
    return None

events = {}
order = []
for raw in audit_text.splitlines():
    line = raw.strip()
    msg = re.search(r"msg=audit\(([^)]+)\):", line)
    if not msg:
        continue
    key = msg.group(1)
    if key not in events:
        events[key] = {}
        order.append(key)
    event = events[key]
    if line.startswith("type=SYSCALL"):
        comm = re.search(r'comm="([^"]+)"', line) or re.search(r"comm=(\S+)", line)
        pid = re.search(r"\bpid=([0-9]+)", line)
        uid = re.search(r"\buid=([0-9]+)", line)
        if comm:
            event["comm"] = comm.group(1)
        if pid:
            event["pid"] = pid.group(1)
        if uid:
            event["uid"] = uid.group(1)
    if "saddr=" in line or "host:" in line:
        sock = re.search(r"saddr=(\S+)", line)
        parsed = parse_sockaddr(sock.group(1) if sock else line)
        if parsed:
            event["dst"] = parsed

flows = {}
for key in order:
    event = events[key]
    dst = event.get("dst")
    if not dst or "pid" not in event:
        continue
    flows[dst] = (event.get("comm") or "inconnu", event["pid"], event.get("uid") or "0")

def emit_plain(lines):
    chosen = lines[:40]
    if chosen:
        sys.stdout.write("\n".join(chosen) + "\n")

if not flows:
    emit_plain(kernel_lines)
    raise SystemExit(0)

groups = []
index = {}
unmatched = []
for line in kernel_lines:
    dst = re.search(r"\bDST=(\S+)", line)
    dpt = re.search(r"\bDPT=([0-9]+)", line)
    proc = None
    if dst and dpt:
        proc = flows.get((dst.group(1), dpt.group(1)))
    if proc is None:
        unmatched.append(line)
        continue
    label = "Processus : %s (pid %s) uid %s" % (proc[0], proc[1], proc[2])
    if label not in index:
        if len(groups) >= 40:
            continue
        index[label] = len(groups)
        groups.append([label, []])
    groups[index[label]][1].append(line)

if unmatched and len(groups) < 40:
    groups.append(["Processus : non associé", unmatched])

blocks = []
for label, lines in groups:
    blocks.append(label)
    for line in lines:
        blocks.append(" → " + line)
if blocks:
    sys.stdout.write("\n".join(blocks) + "\n")
PY
}

hf_write_alert_file() {
    local alert="$1" summary="$2" excerpt="$3" note="$4" note_cmd="$5"
    local dir
    [[ -n "${alert}" ]] || return 0
    dir="$(dirname -- "${alert}")"
    mkdir -p "${dir}" 2>/dev/null || true
    {
        printf '%s\n' "${summary}"
        if [[ -n "${excerpt}" ]]; then
            printf '\n%s\n' "${excerpt}"
        fi
        if [[ -n "${note}" ]]; then
            printf '\n%s\n' "${note}"
        fi
        if [[ -n "${note_cmd}" ]]; then
            printf '\n%s\n' "${note_cmd}"
        fi
    } > "${alert}" || true
}

hf_copy_alert_drive() {
    local alert="${1:-}"
    local base remote path config
    [[ "${HF_RCLONE_ALERTS:-0}" == "1" ]] || return 0
    [[ -n "${alert}" && -f "${alert}" ]] || return 0
    base="$(hf_get_product_base)"
    remote="${HF_RCLONE_REMOTE:-}"
    path="${HF_RCLONE_PATH:-}"
    config="${base}/cron/rclone.conf"
    if [[ -z "${remote}" || -z "${path}" || ! -f "${config}" ]]; then
        printf '%s\n' "Copie Drive ignorée." >&2
        return 0
    fi
    if ! command -v rclone >/dev/null 2>&1; then
        printf '%s\n' "Copie Drive ignorée : rclone absent." >&2
        return 0
    fi
    if ! RCLONE_CONFIG="${config}" rclone copy "${alert}" "${remote}:${path}" >/dev/null 2>&1; then
        printf '%s\n' "Copie Drive refusée. Le fichier local est conservé." >&2
    fi
    return 0
}

hf_log_alert() {
    local summary="$*"
    local excerpt="" module log alert line send base note="" note_cmd=""
    log="${LOG_FILE:-${LOG:-}}"
    alert="${ALERT_FILE:-}"
    excerpt="$(hf_get_alert_excerpt "${log}")"
    line="$(printf '%s %s' "$(date -Iseconds)" "${summary}")"
    if [[ -n "${log}" ]]; then
        printf '%s\n' "${line}" | tee -a "${log}"
    else
        printf '%s\n' "${line}"
    fi
    module="${MODULE_NAME:-}"
    if [[ -z "${module}" && -n "${log}" ]]; then
        module="$(basename "${log}" | sed -E 's/-[0-9]{8}-.*//')"
    fi
    module="${module:-contrôle}"
    base="$(hf_get_product_base)"
    if hf_take_quarantine_note; then
        note=""
        note_cmd=""
    elif [[ "${HFU_AIDE_REFRESH:-}" == "1" ]]; then
        note="Si ce journal correspond à des changements attendus (une mise à jour, un logiciel que vous avez installé, un fichier que vous avez modifié) et qu'il ne révèle pas d'anomalie, exécutez la commande ci-dessous. Elle recalcule la base de référence AIDE à partir du disque actuel."
        note_cmd="sudo bash ${base}/bin/aide-refresh-db.sh"
    elif [[ "${HFU_RKHUNTER_REFRESH:-}" == "1" ]]; then
        hf_prepare_rkhunter_note
        note="${NOTE}"
        note_cmd="${NOTE_CMD}"
    elif [[ "${HFU_CHKROOTKIT_IGNORE:-}" == "1" && -n "${log}" ]]; then
        note="Si les lignes de ce journal sont des faux positifs que vous reconnaissez, et qu'aucune ne révèle une anomalie, exécutez la commande ci-dessous. Elle enregistre ces détections. Le prochain contrôle de chkrootkit ne les signalera plus."
        note_cmd="sudo bash ${base}/bin/chkrootkit-ignore-log.sh '${log}'"
    elif [[ "${HFU_DEBSUMS_IGNORE:-}" == "1" && -n "${log}" ]]; then
        note="Si les lignes de ce journal sont des faux positifs que vous reconnaissez, et qu'aucune ne révèle une anomalie, exécutez la commande ci-dessous. Elle enregistre ces fichiers. Le prochain contrôle de debsums ne les signalera plus."
        note_cmd="sudo bash ${base}/bin/debsums-ignore-log.sh '${log}'"
    fi
    if [[ -z "${NOTE:-}" && -n "${note}" ]]; then
        NOTE="${note}"
        NOTE_CMD="${note_cmd}"
    fi
    if [[ -z "${TITLE:-}" ]]; then
        TITLE="Alerte ${module}"
    fi
    if [[ -z "${HF_PROJECT_NAME:-}" ]]; then
        if [[ -n "${HFU_BASE:-}" ]]; then
            HF_PROJECT_NAME="High-Fortress User"
        else
            HF_PROJECT_NAME="High-Fortress"
        fi
    fi
    hf_write_alert_file "${alert}" "${summary}" "${excerpt}" "${NOTE:-}" "${NOTE_CMD:-}"
    if [[ "${HF_MAIL_ALERTS:-0}" == "1" && -n "${HF_WATCHDOG_MAIL:-}" ]]; then
        send="$(hf_send_path)" || true
        if [[ -n "${send}" ]]; then
            TITLE="${TITLE}" \
            MODULE_NAME="${module}" \
            CONTENT="${summary}

${excerpt}" \
            NOTE="${NOTE:-}" \
            NOTE_CMD="${NOTE_CMD:-}" \
            HF_WATCHDOG_MAIL="${HF_WATCHDOG_MAIL}" \
            HF_PROJECT_NAME="${HF_PROJECT_NAME}" \
            HF_MAIL_TEMPLATE="${HF_MAIL_TEMPLATE:-mail.html}" \
                bash "${send}" || true
        fi
    fi
    hf_copy_alert_drive "${alert}" || true
}

hf_report_clamav() {
    local crashed=0 signal phrase log
    log="${LOG_FILE:-${LOG:-}}"
    [[ -n "${log}" && -f "${log}" ]] || return 1
    crashed="$(grep -c 'planté signal .* sur ' "${log}" || true)"
    [[ "${crashed}" -gt 0 ]] || return 1
    signal="$(sed -n 's/.*planté signal \([0-9][0-9]*\).*/\1/p' "${log}" | head -n 1)"
    phrase="$(hf_signal_phrase "${signal}")"
    if grep -q 'contrôle arrêté' "${log}"; then
        hf_log_alert "ClamAV a planté deux fois de suite (signal ${signal}, ${phrase}). Le contrôle s'est arrêté. Les fichiers restants n'ont pas été analysés."
    elif [[ "${crashed}" -eq 1 ]]; then
        hf_log_alert "ClamAV a planté (signal ${signal}, ${phrase}) sur un fichier. Ce fichier n'a pas été analysé. Les autres fichiers ont été poursuivis."
    else
        hf_log_alert "ClamAV a planté (signal ${signal}, ${phrase}) sur ${crashed} fichiers. Ces fichiers n'ont pas été analysés. Les autres fichiers ont été poursuivis."
    fi
    return 0
}

hf_render_mail_about() {
    case "${MODULE_NAME:-}" in
        Aide) printf '%s\n' "Intégrité des fichiers surveillés par AIDE (aide --check)." ;;
        Chkrootkit) printf '%s\n' "Recherche de rootkits (chkrootkit -x -q)." ;;
        Rkhunter) printf '%s\n' "Recherche de rootkits et fichiers modifiés (rkhunter --check)." ;;
        Clamav) printf '%s\n' "Fichiers signalés par ClamAV (quarantaine et journaux)." ;;
        Auditd) printf '%s\n' "Événements d'audit anormaux (ausearch)." ;;
        Debsums) printf '%s\n' "Fichiers de paquets dont la somme a changé (debsums -c)." ;;
        Fail2ban) printf '%s\n' "Bannissements Fail2Ban des dernières 24 h." ;;
        Crowdsec) printf '%s\n' "Décisions et alertes CrowdSec des dernières 24 h." ;;
        Ufw) printf '%s\n' "Paquets bloqués par UFW." ;;
        Reboot) printf '%s\n' "Un redémarrage est utile. La machine n'a pas été redémarrée." ;;
        *) printf '%s\n' "Message du module ${MODULE_NAME:-inconnu}." ;;
    esac
}

hf_deliver_mail() {
    local script_dir detail _mail_sh _candidate tpl
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd)"
    detail="$(printf '%s' "${CONTENT:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ -z "${detail}" ]]; then
        echo "Mail non envoyé (${MODULE_NAME:-?}) : corps vide." >&2
        exit 0
    fi
    if [[ "${HF_MAIL_ABOUT:-0}" == "1" ]]; then
        CONTENT="$(hf_render_mail_about)

${detail}"
    else
        CONTENT="${detail}"
    fi
    HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
    DATE="${DATE:-$(date '+%Y-%m-%d %H:%M:%S')}"
    TITLE="${TITLE:-Alerte}"
    MODULE_NAME="${MODULE_NAME:-alerte}"
    if [[ -z "${HF_PROJECT_NAME:-}" ]]; then
        if [[ -n "${HFU_BASE:-}" ]]; then
            HF_PROJECT_NAME="High-Fortress User"
        else
            HF_PROJECT_NAME="High-Fortress"
        fi
    fi
    export TITLE HF_PROJECT_NAME HOSTNAME DATE MODULE_NAME CONTENT
    export NOTE="${NOTE:-}"
    export NOTE_CMD="${NOTE_CMD:-}"
    _mail_sh=""
    for _candidate in \
        "${script_dir}/mail.sh" \
        "${HF_CONFIG_BASE_DIRECTORY:-}/cron/bin/mail.sh" \
        "${HF_CONFIG_BASE_DIRECTORY:-}/src/core/mail.sh" \
        "${HF_INSTALL_DIRECTORY:-}/core/mail.sh" \
        "${HF_INSTALL_DIRECTORY:-}/../core/mail.sh" \
        "${script_dir}/../../../core/mail.sh" \
        "${script_dir}/../../../../core/mail.sh" \
        "${script_dir}/../core/mail.sh" \
        "${script_dir}/../../core/mail.sh" \
        "${script_dir}/../../src/core/mail.sh"
    do
        if [[ -n "${_candidate}" && -f "${_candidate}" ]]; then
            _mail_sh="${_candidate}"
            break
        fi
    done
    if [[ -z "${_mail_sh}" ]]; then
        echo "Mail non envoyé (${MODULE_NAME}) : core/mail.sh introuvable." >&2
        exit 0
    fi
    # shellcheck disable=SC1090
    source "${_mail_sh}"
    tpl="$(hf_locate_mail_template "${script_dir}")" || {
        echo "Mail non envoyé (${MODULE_NAME}) : modèle HTML introuvable." >&2
        exit 0
    }
    if [[ "${HF_MAIL_REDACT:-0}" == "1" ]]; then
        if ! MAIL_CONTENT="$(HF_MAIL_REDACT=1 hf_render_mail "${tpl}")"; then
            echo "Mail non envoyé (${MODULE_NAME}) : modèle HTML invalide." >&2
            exit 0
        fi
    elif ! MAIL_CONTENT="$(hf_render_mail "${tpl}")"; then
        echo "Mail non envoyé (${MODULE_NAME}) : modèle HTML invalide." >&2
        exit 0
    fi
    if [[ -n "${HTML_REPORT:-}" ]]; then
        printf '%s\n' "${MAIL_CONTENT}" > "${HTML_REPORT}" || true
        hf_copy_alert_drive "${HTML_REPORT}" || true
    fi
    if [[ "${HF_MAIL_REQUIRE_FLAG:-0}" == "1" ]]; then
        if [[ "${HF_MAIL_ALERTS:-0}" != "1" || -z "${HF_WATCHDOG_MAIL:-}" ]]; then
            echo "Mail non envoyé (${MODULE_NAME:-?}) : alertes e-mail coupées." >&2
            exit 0
        fi
    elif [[ -z "${HF_WATCHDOG_MAIL:-}" ]]; then
        echo "Mail non envoyé (${MODULE_NAME:-?}) : destinataire ou corps vide." >&2
        exit 0
    fi
    if ! command -v mail >/dev/null 2>&1; then
        echo "Mail non envoyé (${MODULE_NAME:-?}) : commande mail absente." >&2
        exit 0
    fi
    printf '%s\n' "${MAIL_CONTENT}" | mail -s "${HF_PROJECT_NAME} - ${HOSTNAME} - ${MODULE_NAME}" \
        -a "Content-Type: text/html; charset=UTF-8" \
        "${HF_WATCHDOG_MAIL}"
}
