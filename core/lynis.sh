#!/usr/bin/env bash
# Audit Lynis. Un seul corps pour les deux produits.
# Usage : bash core/lynis.sh <racine du produit> [auditeur]
# Sans auditeur : PROJECT_SLUG de global.conf, sinon high-fortress.
set -euo pipefail

root="${1:-}"
auditor="${2:-}"
if [[ -z "${root}" || ! -d "${root}" ]]; then
    printf 'usage: lynis.sh <racine> [auditeur]\n' >&2
    exit 2
fi
if [[ -z "${auditor}" && -f "${root}/global.conf" ]]; then
    auditor="$(awk -F= '/^PROJECT_SLUG=/{gsub(/["'\'']/, "", $2); gsub(/[[:space:]]/, "", $2); print $2; exit}' "${root}/global.conf")"
fi
auditor="${auditor:-high-fortress}"
if [[ "${EUID}" -ne 0 ]]; then
    printf 'Lynis audit system nécessite root (sudo).\n' >&2
    exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"
out="${root}/logs/lynis-${stamp}"
mkdir -p "${out}"
lynis audit system --quick --no-colors --auditor "${auditor}" | tee "${out}/lynis-audit.txt"
cp -a /var/log/lynis.log "${out}/lynis.log" 2>/dev/null || true
cp -a /var/log/lynis-report.dat "${out}/lynis-report.dat" 2>/dev/null || true
chmod 640 /var/log/lynis.log /var/log/lynis-report.dat 2>/dev/null || true
{
    echo "=== hostname ==="; hostname; uname -a
    echo "=== score ==="; grep -E "hardening_index|lynis_tests_done" /var/log/lynis-report.dat || true
    echo "=== warnings ==="; grep -E "^warning\[\]=" /var/log/lynis-report.dat || true
    echo "=== suggestions ==="; grep -E "^suggestion\[\]=" /var/log/lynis-report.dat || true
} > "${out}/summary.txt"
printf 'Rapport : %s\n' "${out}"
