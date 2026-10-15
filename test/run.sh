#!/usr/bin/env bash
# =============================================================================
# File       : test/run.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

set -euo pipefail

HFT_TEST_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HFT_ROOT="$(cd -- "${HFT_TEST_DIRECTORY}/.." && pwd)"

PROFILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            if [[ -z "${PROFILE}" ]]; then
                echo "Missing value for --profile" >&2
                exit 2
            fi
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--profile MATRIX|LIVEKIT|WIREGUARD|ALL|WORKSTATION]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "${PROFILE}" ]]; then
    if [[ -f "${HFT_ROOT}/config/global.conf" ]] && grep -qE '^(HFS_SERVER_TYPE="WORKSTATION"|HFU_PROJECT_SLUG="high-fortress-user")$' "${HFT_ROOT}/config/global.conf"; then
        PROFILE="WORKSTATION"
    else
        PROFILE="ALL"
    fi
fi

case "${PROFILE}" in
    MATRIX|LIVEKIT|WIREGUARD|ALL|WORKSTATION) ;;
    *)
        echo "Invalid --profile: ${PROFILE}" >&2
        exit 2
        ;;
esac

product_ws=0
if [[ -f "${HFT_ROOT}/config/global.conf" ]] && grep -qE '^(HFS_SERVER_TYPE="WORKSTATION"|HFU_PROJECT_SLUG="high-fortress-user")$' "${HFT_ROOT}/config/global.conf"; then
    product_ws=1
fi
if [[ "${product_ws}" -eq 1 && "${PROFILE}" != "WORKSTATION" ]]; then
    echo "Profil ${PROFILE} refusé pour le poste." >&2
    exit 2
fi
if [[ "${product_ws}" -eq 0 && "${PROFILE}" == "WORKSTATION" ]]; then
    echo "Profil WORKSTATION refusé pour le serveur." >&2
    exit 2
fi

if [[ -f "${HFT_ROOT}/core/test-harness.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HFT_ROOT}/core/test-harness.sh"
elif [[ -f "${HFT_ROOT}/../core/test-harness.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HFT_ROOT}/../core/test-harness.sh"
else
    printf 'test-harness.sh introuvable depuis %s\n' "${HFT_ROOT}" >&2
    exit 1
fi

if [[ -f "${HFT_TEST_DIRECTORY}/lib.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HFT_TEST_DIRECTORY}/lib.sh"
fi

hft_begin
hft_run_suite
hft_finish
