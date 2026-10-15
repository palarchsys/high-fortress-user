#!/usr/bin/env bash
# =============================================================================
# File       : system/collect-logs.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1:-}"
if [[ -z "$HF_INSTALL_DIRECTORY" ]]; then
    HF_INSTALL_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
fi
export HF_INSTALL_DIRECTORY

# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/config/global.conf"

hf_require_root
hf_collect_manual
