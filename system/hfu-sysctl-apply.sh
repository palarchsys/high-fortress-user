#!/usr/bin/env bash
# =============================================================================
# Fichier    : system/hfu-sysctl-apply.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Applique le fichier sysctl du poste au démarrage.
# =============================================================================

# Certaines clés du profil Lynis n'existent pas, ou sont en lecture
# seule, sur le noyau de la machine. Elles sont ignorées. Le service
# reste réussi : une clé refusée ne doit pas marquer le démarrage.
# =============================================================================
set -u
conf="/etc/sysctl.d/99-zzz-high-fortress-user.conf"
[[ -f "${conf}" ]] || exit 0
while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "${line}" ]] && continue
    [[ "${line}" == *=* ]] || continue
    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    val="${line#*=}"
    val="${val#"${val%%[![:space:]]*}"}"
    # Le message de sysctl est dans la langue du système. On ne le
    # lit pas : une clé absente de /proc/sys n'existe pas sur ce noyau.
    proc="/proc/sys/${key//.//}"
    if [[ ! -e "${proc}" ]]; then
        printf 'ignoré: %s absent\n' "${key}" >&2
        continue
    fi
    err="$(sysctl -w "${key}=${val}" 2>&1)" && continue
    current="$(sysctl -n "${key}" 2>/dev/null || true)"
    if [[ "${current}" == "${val}" ]]; then
        continue
    fi
    # Lecture seule ou valeur refusée : le démarrage continue.
    printf 'ignoré: %s\n' "${err}" >&2
done < "${conf}"
exit 0
