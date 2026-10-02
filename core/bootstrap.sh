#!/usr/bin/env bash
# Résolution de core/ pour le monodépôt (../core) et pour une archive
# publiée (./core à côté de lib.sh). HF_PRODUCT_ROOT est posé par l'appelant.

hf_source_core() {
    local name="$1"
    local candidate
    local -a candidates=(
        "${HF_PRODUCT_ROOT}/../core/${name}"
        "${HF_PRODUCT_ROOT}/core/${name}"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -f "${candidate}" ]]; then
            # shellcheck disable=SC1090
            source "${candidate}"
            return 0
        fi
    done
    printf 'core/%s introuvable (HF_PRODUCT_ROOT=%s)\n' "${name}" "${HF_PRODUCT_ROOT}" >&2
    exit 1
}
