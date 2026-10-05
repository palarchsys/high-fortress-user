#!/usr/bin/env bash
# =============================================================================
# File       : system/collect-logs.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1:-}"
if [[ -z "$DIR_INSTALL_PATH" ]]; then
    DIR_INSTALL_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
fi
export DIR_INSTALL_PATH

# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/core/lib.sh"
# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/global.conf"

require_root
hf_collect_manual
