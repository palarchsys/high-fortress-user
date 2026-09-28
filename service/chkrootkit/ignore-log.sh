#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/chkrootkit/ignore-log.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Enregistre comme faux positifs les lignes d'un journal chkrootkit.
# =============================================================================

# Copié vers /opt/high-fortress-user/bin/chkrootkit-ignore-log.sh.
# Le courriel d'alerte indique cette commande, avec le journal joint.
# Les lignes sont ajoutées à cron/chkrootkit.local.ignore. Ce fichier
# reste en place quand l'installateur recopie les contrôles.
# Une ligne est comparée telle quelle : une détection différente
# (autre numéro de processus, autre date) produit encore une alerte.
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lancez cette commande avec sudo.\n' >&2
    exit 1
fi
if [[ $# -ne 1 || ! -f "$1" ]]; then
    printf 'Indiquez le journal chkrootkit cité dans le courriel.\n' >&2
    printf 'Exemple : sudo bash %s/bin/chkrootkit-ignore-log.sh %s/cron/security_logs/chkrootkit-DATE.log\n' \
        "${HFU_BASE}" "${HFU_BASE}" >&2
    exit 1
fi

python3 - "${HFU_BASE}" "$1" << 'PY'
import re
import sys
from pathlib import Path

base = Path(sys.argv[1]).resolve()
log_path = Path(sys.argv[2]).resolve()
logs = (base / "cron" / "security_logs").resolve()
local = base / "cron" / "chkrootkit.local.ignore"
shipped = base / "cron" / "bin" / "chkrootkit.ignore"

try:
    log_path.relative_to(logs)
except ValueError:
    sys.stderr.write("Ce journal n'est pas un relevé chkrootkit du poste.\n")
    sys.exit(1)
if not log_path.name.startswith("chkrootkit-") or log_path.suffix != ".log":
    sys.stderr.write("Le fichier attendu se nomme chkrootkit-DATE.log.\n")
    sys.exit(1)

headers = {
    "WARNING: The following suspicious files and directories were found:",
    "WARNING: Possible Linux BPFDoor Malware installed:",
    "WARNING: output from chkwtmp:",
    "WARNING: Output from ifpromisc:",
}

def load_patterns(path):
    found = []
    if not path.is_file():
        return found
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            found.append((line, re.compile(line)))
        except re.error:
            sys.stderr.write(f"Expression ignorée, elle est invalide : {line}\n")
    return found

known = load_patterns(shipped) + load_patterns(local)
known_text = {text for text, _ in known}

def already(line):
    return any(pat.search(line) for _, pat in known)

added = []
for raw in log_path.read_text(errors="replace").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or line in headers:
        continue
    if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T", line):
        continue
    if line.startswith("chkrootkit a produit une sortie"):
        continue
    if already(line):
        continue
    pattern = "^" + re.escape(line) + "$"
    if pattern in known_text or pattern in added:
        continue
    added.append(pattern)

if not added:
    print("Aucune nouvelle détection à enregistrer.")
    sys.exit(0)

local.parent.mkdir(parents=True, exist_ok=True)
block = ["", "# Détections acceptées depuis un courriel chkrootkit."]
block.extend(added)
existing = local.read_text(errors="replace") if local.is_file() else (
    "# Faux positifs ajoutés par l'administrateur du poste.\n"
    "# Une expression Python par ligne. Pas de ligne vide.\n"
)
text = existing.rstrip("\n") + "\n" + "\n".join(block).lstrip("\n")
if not text.endswith("\n"):
    text += "\n"
tmp = local.with_suffix(".ignore.tmp")
tmp.write_text(text, encoding="utf-8")
tmp.replace(local)
print(f"{len(added)} détection(s) enregistrée(s) dans {local}")
for pattern in added:
    print(pattern)
PY
