#!/usr/bin/env bash
# =============================================================================
# File       : test/run.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

set -euo pipefail

HF_TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HF_ROOT="$(cd -- "${HF_TEST_DIR}/.." && pwd)"

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
    if [[ -f "${HF_ROOT}/config/global.conf" ]] && grep -qE '^(SERVER_TYPE="WORKSTATION"|PROJECT_SLUG="high-fortress-user")$' "${HF_ROOT}/config/global.conf"; then
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
if [[ -f "${HF_ROOT}/config/global.conf" ]] && grep -qE '^(SERVER_TYPE="WORKSTATION"|PROJECT_SLUG="high-fortress-user")$' "${HF_ROOT}/config/global.conf"; then
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

if [[ -f "${HF_ROOT}/core/test-harness.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HF_ROOT}/core/test-harness.sh"
elif [[ -f "${HF_ROOT}/../core/test-harness.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HF_ROOT}/../core/test-harness.sh"
else
    printf 'test-harness.sh introuvable depuis %s\n' "${HF_ROOT}" >&2
    exit 1
fi

if [[ -f "${HF_TEST_DIR}/lib.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HF_TEST_DIR}/lib.sh"
fi

hf_test_begin
hf_test_run_suites
hf_test_finish
