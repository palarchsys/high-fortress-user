#!/usr/bin/env bash
# =============================================================================
# lynis.sh — contrôle Lynis à la demande
# =============================================================================
# Lynis parcourt la configuration et écrit un indice de durcissement.
# Le rapport est copié dans logs/ à côté de ce script.
# Lancer : sudo bash lynis.sh
# =============================================================================
set -euo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${DIR}/logs/lynis-${STAMP}"
mkdir -p "${OUT}"
if [[ "${EUID}" -ne 0 ]]; then
    echo "Lynis audit system nécessite root (sudo)." >&2
    exit 1
fi
lynis audit system --quick --no-colors --auditor high-fortress-user | tee "${OUT}/lynis-audit.txt"
cp -a /var/log/lynis.log "${OUT}/lynis.log" 2>/dev/null || true
cp -a /var/log/lynis-report.dat "${OUT}/lynis-report.dat" 2>/dev/null || true
chmod 640 /var/log/lynis.log /var/log/lynis-report.dat 2>/dev/null || true
{
  echo "=== hostname ==="; hostname; uname -a
  echo "=== score ==="; grep -E "hardening_index|lynis_tests_done" /var/log/lynis-report.dat || true
  echo "=== warnings ==="; grep -E "^warning\[\]=" /var/log/lynis-report.dat || true
  echo "=== suggestions ==="; grep -E "^suggestion\[\]=" /var/log/lynis-report.dat || true
} > "${OUT}/summary.txt"
echo "Rapport : ${OUT}"
