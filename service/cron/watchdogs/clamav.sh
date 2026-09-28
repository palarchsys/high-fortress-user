#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/watchdogs/clamav.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   Parcourt ce que la surveillance continue ne voit pas.
# =============================================================================

# Appelé par la passe de démarrage, sous le même plafond processeur
# et la même classe d'entrées-sorties que AIDE, rkhunter et chkrootkit.
# Les Téléchargements et le Bureau restent à clamonacc : ce parcours
# les saute. Si clamd tourne, clamdscan lui envoie les fichiers au lieu
# d'ouvrir une seconde base de signatures.
# =============================================================================

set -euo pipefail
HFU_BASE="${HFU_BASE:-/opt/high-fortress-user}"
# shellcheck disable=SC1091
source "${HFU_BASE}/cron/bin/common.sh"
LOG_FILE="${LOG_DIR}/clamav-${STAMP}.log"
ALERT_FILE="${ALERT_DIR}/clamav-${STAMP}.txt"
if ! command -v clamscan >/dev/null && ! command -v clamdscan >/dev/null; then
    log_ok "clamscan absent — skip"
    exit 0
fi

# Chemins déjà couverts à l'ouverture par clamonacc.
onaccess=()
if [[ -f /etc/clamav/clamd.conf ]]; then
    while read -r _ path; do
        [[ -n "${path}" ]] && onaccess+=("${path}")
    done < <(awk '/^OnAccessIncludePath[[:space:]]/{print $1, $2}' /etc/clamav/clamd.conf)
fi

# Morceaux de chemin écartés, comme le passage historique du lundi.
prune_names=(
    .steam Steam .local/share/Steam .cache snap
    proc sys dev
    var/lib/libvirt var/lib/docker
    BraveSoftware .config/discord
    .thunderbird thunderbird libvirt
    snap-private-tmp
)

find_args=()
for path in "${onaccess[@]}"; do
    find_args+=( -path "${path}" -o -path "${path}/*" -o )
done
for name in "${prune_names[@]}"; do
    find_args+=( -path "*/${name}" -o -path "*/${name}/*" -o )
done
unset 'find_args[-1]'

file_list="$(mktemp)"
trap 'rm -f "${file_list}"' EXIT
find /home /opt /tmp \
    \( "${find_args[@]}" \) -prune -o -type f -print0 \
    > "${file_list}" 2>>"${LOG_FILE}" || true

set +e
if clamdscan --ping 3 >/dev/null 2>&1; then
    xargs -0 -r -n 80 clamdscan --fdpass --infected < "${file_list}" >> "${LOG_FILE}" 2>&1
    rc=$?
    # xargs rend 123 quand clamdscan signale un fichier (code 1).
    if [[ "${rc}" -eq 123 ]] && grep -q 'FOUND' "${LOG_FILE}"; then
        rc=1
    fi
else
    exclude=()
    for path in "${onaccess[@]}"; do
        escaped="$(printf '%s' "${path}" | sed 's/[.[\*^$()+?{|]/\\&/g')"
        exclude+=( --exclude-dir="${escaped}" )
    done
    for name in "${prune_names[@]}"; do
        exclude+=( --exclude-dir="/${name}" )
    done
    clamscan -ri /home /opt /tmp "${exclude[@]}" >> "${LOG_FILE}" 2>&1
    rc=$?
fi
set -e

if [[ "${rc}" -ge 2 ]]; then
    log_alert "clamscan erreur rc=${rc}"
elif [[ "${rc}" -eq 1 ]]; then
    log_alert "clamscan : infection(s) (voir ${LOG_FILE})"
else
    log_ok "clamscan OK"
fi
exit 0
