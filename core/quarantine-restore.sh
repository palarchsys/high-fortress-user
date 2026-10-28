#!/usr/bin/env bash
# =============================================================================
# File       : core/quarantine-restore.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Put one recorded file back at its original path.
# Note       : The registry line is the only accepted origin.
# -----------------------------------------------------------------------------

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    printf '%s\n' "root requis" >&2
    exit 1
fi

if [[ "$#" -ne 1 || -z "${1:-}" ]]; then
    printf '%s\n' "un identifiant est requis" >&2
    exit 1
fi

id="$1"
if [[ ! "${id}" =~ ^[0-9]{8}-[0-9]{6}-[0-9]+- ]]; then
    printf '%s\n' "identifiant refusé" >&2
    exit 1
fi
case "${id}" in
    */*|*\\*)
        printf '%s\n' "identifiant refusé" >&2
        exit 1
        ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename -- "${script_dir}")" == "bin" ]]; then
    base="$(dirname -- "${script_dir}")"
else
    base="${G_CONFIG_BASE_DIRECTORY:-${W_BASE:-${G_BASE:-/opt/liltress}}}"
fi

registry="${base}/cron/quarantine.registry"
if [[ ! -f "${registry}" ]]; then
    printf '%s\n' "identifiant absent du registre" >&2
    exit 1
fi

line="$(awk -F '\t' -v want="${id}" '$1 == want { print; exit }' "${registry}")"
if [[ -z "${line}" ]]; then
    printf '%s\n' "identifiant absent du registre" >&2
    exit 1
fi

IFS=$'\t' read -r found_id _moment _source origin stored _signature <<< "${line}"
if [[ "${found_id}" != "${id}" || -z "${origin}" || -z "${stored}" ]]; then
    printf '%s\n' "identifiant absent du registre" >&2
    exit 1
fi
case "${origin}" in
    /*) ;;
    *)
        printf '%s\n' "emplacement d'origine refusé" >&2
        exit 1
        ;;
esac

if [[ ! -e "${stored}" ]]; then
    printf '%s\n' "fichier de quarantaine absent" >&2
    exit 1
fi

parent="$(dirname -- "${origin}")"
if [[ ! -d "${parent}" ]]; then
    printf '%s\n' "répertoire d'origine absent" >&2
    exit 1
fi

if [[ -e "${origin}" ]]; then
    printf '%s\n' "emplacement d'origine occupé" >&2
    exit 1
fi

mv -- "${stored}" "${origin}"
printf '%s\n' "fichier remis en place"
exit 0
