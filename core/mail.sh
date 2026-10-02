#!/usr/bin/env bash
# core/mail.sh — modèles HTML des deux installeurs.
# L'opérateur dépose un ou plusieurs fichiers .html dans template/.
# MAIL_TEMPLATE (global.conf) choisit le fichier envoyé. Défaut : mail.html.
# Chaque send.sh garde sa politique : alertes, masquage, objet, pièce jointe.

hf_mail_template_name_ok() {
    [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.html$ ]]
}

hf_mail_die() {
    if declare -F error >/dev/null 2>&1; then
        error "$*"
    fi
    printf '%s\n' "$*" >&2
    exit 1
}

# Copie tous les .html de template/ vers le dossier cron installé.
# Le fichier nommé par MAIL_TEMPLATE doit faire partie de la copie.
hf_install_mail_templates() {
    local dest="$1"
    local src="${DIR_INSTALL_PATH:?}/template"
    local chosen="${MAIL_TEMPLATE:-mail.html}"
    local f base n=0
    local glob_state
    [[ -d "${dest}" ]] || hf_mail_die "dossier d'installation des modèles absent (${dest})"
    [[ -d "${src}" ]] || hf_mail_die "dossier template absent (${src})"
    hf_mail_template_name_ok "${chosen}" || hf_mail_die "MAIL_TEMPLATE invalide (${chosen}). exemple : mail.html"
    glob_state="$(shopt -p nullglob)"
    shopt -s nullglob
    for f in "${src}/"*.html; do
        base="$(basename -- "${f}")"
        hf_mail_template_name_ok "${base}" || hf_mail_die "nom de modèle refusé (${base}). exemple : mail.html"
        cp -f -- "${f}" "${dest}/${base}"
        chmod 644 "${dest}/${base}"
        n=$((n + 1))
    done
    eval "${glob_state}"
    [[ "${n}" -ge 1 ]] || hf_mail_die "aucun fichier .html dans ${src}"
    [[ -f "${dest}/${chosen}" ]] || hf_mail_die "modèle ${chosen} absent de ${src}"
}

# Nom du modèle. global.conf gagne sur la variable d'environnement,
# pour qu'une édition du fichier soit prise au prochain envoi.
hf_mail_resolve_name() {
    local here="${1:-}"
    local conf line
    local -a confs=()
    [[ -n "${DIR_INSTALL_PATH:-}" ]] && confs+=("${DIR_INSTALL_PATH}/global.conf")
    [[ -n "${CONFIG_BASE_DIR:-}" ]] && confs+=("${CONFIG_BASE_DIR}/src/global.conf")
    if [[ -n "${here}" ]]; then
        confs+=(
            "${here}/../../src/global.conf"
            "${here}/../../../global.conf"
            "${here}/../global.conf"
        )
    fi
    for conf in "${confs[@]}"; do
        [[ -f "${conf}" ]] || continue
        line="$(awk -F= '/^MAIL_TEMPLATE=/{gsub(/"/,"",$2); gsub(/[[:space:]]/,"",$2); print $2; exit}' "${conf}")"
        if [[ -n "${line}" ]]; then
            printf '%s\n' "${line}"
            return 0
        fi
    done
    if [[ -n "${MAIL_TEMPLATE:-}" ]]; then
        printf '%s\n' "${MAIL_TEMPLATE}"
        return 0
    fi
    printf '%s\n' "mail.html"
}

# Chemin du modèle à rendre. Les sources (template/) passent avant la copie cron.
hf_mail_template_file() {
    local here="${1:-}"
    local name dir
    local -a dirs=()
    name="$(hf_mail_resolve_name "${here}")"
    hf_mail_template_name_ok "${name}" || return 1
    [[ -n "${DIR_INSTALL_PATH:-}" ]] && dirs+=("${DIR_INSTALL_PATH}/template")
    [[ -n "${CONFIG_BASE_DIR:-}" ]] && dirs+=("${CONFIG_BASE_DIR}/src/template")
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

# Rend le HTML sur stdout. HF_MAIL_REDACT=1 masque clés et secrets dans le corps.
# Code 1 si le fichier manque ou si le résultat n'a pas de balise pre.
hf_render_mail() {
    local template="$1"
    [[ -f "${template}" ]] || return 1
    HF_MAIL_TEMPLATE_FILE="${template}" \
    HF_MAIL_REDACT="${HF_MAIL_REDACT:-0}" \
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

redact_on = os.environ.get("HF_MAIL_REDACT", "0") == "1"
content = os.environ.get("CONTENT", "")
note = os.environ.get("NOTE", "")
if redact_on:
    content = redact(content)
    note = redact(note)
note = note.strip()
note_cmd = os.environ.get("NOTE_CMD", "").strip()
path = Path(os.environ["HF_MAIL_TEMPLATE_FILE"])
try:
    tpl = path.read_text(encoding="utf-8")
except OSError as exc:
    print(f"modèle illisible : {exc}", file=sys.stderr)
    sys.exit(1)
for key in ("TITLE", "PROJECT_NAME", "HOSTNAME", "DATE", "MODULE_NAME"):
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
