#!/usr/bin/env bash
# =============================================================================
# File       : core/mail.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

g_check_mail_template_name() {
    [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.html$ ]]
}

g_log_mail_fatal() {
    if declare -F g_log_error >/dev/null 2>&1; then
        g_log_error "$*"
    fi
    printf '%s\n' "$*" >&2
    exit 1
}

g_install_mail_templates() {
    local dest="$1"
    local src="${G_INSTALL_DIRECTORY:?}/template"
    local chosen="${G_MAIL_TEMPLATE:-mail.html}"
    local f base n=0
    local nullglob_was=0
    [[ -d "${dest}" ]] || g_log_mail_fatal "dossier d'installation des modèles absent (${dest})"
    [[ -d "${src}" ]] || g_log_mail_fatal "dossier template absent (${src})"
    g_check_mail_template_name "${chosen}" || g_log_mail_fatal "G_MAIL_TEMPLATE invalide (${chosen}). exemple : mail.html"

    if shopt -q nullglob; then
        nullglob_was=1
    fi
    shopt -s nullglob
    for f in "${src}/"*.html; do
        base="$(basename -- "${f}")"
        g_check_mail_template_name "${base}" || g_log_mail_fatal "nom de modèle refusé (${base}). exemple : mail.html"
        cp -f -- "${f}" "${dest}/${base}"
        chmod 644 "${dest}/${base}"
        n=$((n + 1))
    done
    if [[ "${nullglob_was}" -eq 0 ]]; then
        shopt -u nullglob
    fi
    [[ "${n}" -ge 1 ]] || g_log_mail_fatal "aucun fichier .html dans ${src}"
    [[ -f "${dest}/${chosen}" ]] || g_log_mail_fatal "modèle ${chosen} absent de ${src}"
}

g_get_mail_name() {
    local here="${1:-}"
    local conf line
    local -a confs=()
    [[ -n "${G_INSTALL_DIRECTORY:-}" ]] && confs+=("${G_INSTALL_DIRECTORY}/config/global.conf")
    [[ -n "${G_CONFIG_BASE_DIRECTORY:-}" ]] && confs+=("${G_CONFIG_BASE_DIRECTORY}/src/config/global.conf")
    if [[ -n "${here}" ]]; then
        confs+=(
            "${here}/../../src/config/global.conf"
            "${here}/../../../config/global.conf"
            "${here}/../config/global.conf"
        )
    fi
    for conf in "${confs[@]}"; do
        [[ -f "${conf}" ]] || continue
        line="$(awk -F= '/^G_MAIL_TEMPLATE=/{gsub(/"/,"",$2); gsub(/[[:space:]]/,"",$2); print $2; exit}' "${conf}")"
        if [[ -n "${line}" ]]; then
            printf '%s\n' "${line}"
            return 0
        fi
    done
    if [[ -n "${G_MAIL_TEMPLATE:-}" ]]; then
        printf '%s\n' "${G_MAIL_TEMPLATE}"
        return 0
    fi
    printf '%s\n' "mail.html"
}

g_locate_mail_template() {
    local here="${1:-}"
    local name dir
    local -a dirs=()
    name="$(g_get_mail_name "${here}")"
    g_check_mail_template_name "${name}" || return 1
    [[ -n "${G_INSTALL_DIRECTORY:-}" ]] && dirs+=("${G_INSTALL_DIRECTORY}/template")
    [[ -n "${G_CONFIG_BASE_DIRECTORY:-}" ]] && dirs+=("${G_CONFIG_BASE_DIRECTORY}/src/template")
    if [[ -n "${here}" ]]; then
        dirs+=(
            "${here}/../../src/template"
            "${here}/../../../template"
            "${here}/../template"
            "${here}"
        )
    fi
    for dir in "${dirs[@]}"; do
        if [[ -f "${dir}/${name}" ]]; then
            printf '%s\n' "${dir}/${name}"
            return 0
        fi
    done
    return 1
}

g_render_mail() {
    local template="$1"
    [[ -f "${template}" ]] || return 1
    G_MAIL_TEMPLATE_FILE="${template}" \
    G_MAIL_REDACT="${G_MAIL_REDACT:-0}" \
    python3 - << 'PY'
import html
import os
import re
import sys
from pathlib import Path

def redact(text):
    text = re.sub(
        r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----",
        "[masqué]",
        text,
        flags=re.S,
    )
    text = re.sub(r"(?i)\bbearer\s+(?!\[masqué\])\S+", "Bearer [masqué]", text)
    text = re.sub(
        r"(?i)\b(password|passwd|token|jeton|api[_-]?key|secret|authorization|private[_-]?key|clé privée|clef privée)\b(\s*[:=]\s*)(?!\[masqué\])\S+",
        lambda m: m.group(1) + m.group(2) + "[masqué]",
        text,
    )
    return text

redact_on = os.environ.get("G_MAIL_REDACT", "0") == "1"
content = os.environ.get("CONTENT", "")
note = os.environ.get("NOTE", "")
if redact_on:
    content = redact(content)
    note = redact(note)
note = note.strip()
note_cmd = os.environ.get("NOTE_CMD", "").strip()
path = Path(os.environ["G_MAIL_TEMPLATE_FILE"])
try:
    tpl = path.read_text(encoding="utf-8")
except OSError as exc:
    print(f"modèle illisible : {exc}", file=sys.stderr)
    sys.exit(1)
for key in ("TITLE", "G_PROJECT_NAME", "HOSTNAME", "DATE", "MODULE_NAME"):
    tpl = tpl.replace("${" + key + "}", html.escape(os.environ.get(key, ""), quote=False))
tpl = tpl.replace("${CONTENT}", html.escape(content, quote=False))
if note and note_cmd:
    tpl = tpl.replace("${NOTE}", html.escape(note, quote=False))
    tpl = tpl.replace("${NOTE_CMD}", html.escape(note_cmd, quote=False))
else:
    tpl = re.sub(r"<!--NOTE_START-->.*?<!--NOTE_END-->", "", tpl, count=1, flags=re.S)
if "<pre" not in tpl:
    print("modèle sans balise pre", file=sys.stderr)
    sys.exit(1)
sys.stdout.write(tpl)
PY
}
