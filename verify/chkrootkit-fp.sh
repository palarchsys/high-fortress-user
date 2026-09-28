#!/usr/bin/env bash
# =============================================================================
# Fichier    : verify/chkrootkit-fp.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Script temporaire. Après une installation fraîche et un redémarrage,
#   il relance chkrootkit exactement comme la passe de démarrage
#   (chkrootkit -q) et affiche toute la sortie. Ces lignes sont les
#   faux positifs du poste terminé : elles servent à écrire la liste
#   d'exclusion de l'installateur.
#
# Lancer, une fois la machine redémarrée :
#   sudo bash verify/chkrootkit-fp.sh
# =============================================================================

set +e

if [[ "${EUID}" -ne 0 ]]; then
    echo "Lancez ce script avec sudo : sudo bash verify/chkrootkit-fp.sh" >&2
    exit 1
fi

if ! command -v chkrootkit >/dev/null 2>&1; then
    echo "chkrootkit est absent." >&2
    exit 1
fi

log_dir="/var/log/high-fortress-user"
mkdir -p "${log_dir}"
stamp="$(date +%Y%m%d-%H%M%S)"
log_file="${log_dir}/chkrootkit-fp-${stamp}.log"
version="$(chkrootkit -V 2>&1 | head -5)"

{
    echo "High-Fortress User — relevé chkrootkit (faux positifs)"
    echo "date : $(date -Iseconds)"
    echo "hôte : $(hostname)"
    echo "démarrage : $(uptime -s 2>/dev/null || who -b)"
    echo "commande : chkrootkit -q"
    echo "version :"
    printf '%s\n' "${version}"
    echo
    echo "===== SORTIE ====="
} | tee "${log_file}"

echo "Le contrôle peut prendre plusieurs minutes."
chkrootkit -q >> "${log_file}" 2>&1
rc=$?

if [[ "$(tail -n 1 "${log_file}")" == "===== SORTIE =====" ]]; then
    {
        echo "(aucune ligne : chkrootkit -q est resté silencieux)"
    } | tee -a "${log_file}"
fi

{
    echo
    echo "===== FIN ====="
    echo "code de retour : ${rc}"
    echo "journal : ${log_file}"
    echo "Copiez toute cette sortie pour constituer la liste d'exclusion."
} | tee -a "${log_file}"

exit 0
