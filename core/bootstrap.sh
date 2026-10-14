#!/usr/bin/env bash
# =============================================================================
# File       : core/bootstrap.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

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
