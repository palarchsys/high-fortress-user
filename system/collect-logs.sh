#!/usr/bin/env bash
# =============================================================================
# system/collect-logs.sh — snapshot manuel des journaux du poste
# =============================================================================
# Usage : sudo bash system/collect-logs.sh
# HF_DEBUG_INSTALL_LOGS=1 ou DEBUG_INSTALL_LOGS=1 → logs/ dans le dépôt.
# Sinon → /var/log/high-fortress-user/.
# L'empreinte des comptes (human.tsv) reste sur la machine, en mode 600.
# =============================================================================

DIR_INSTALL_PATH="${1:-}"
if [[ -z "$DIR_INSTALL_PATH" ]]; then
    DIR_INSTALL_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
fi
export DIR_INSTALL_PATH

# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/lib.sh"
# shellcheck disable=SC1091
source "${DIR_INSTALL_PATH}/global.conf"

require_root
hf_collect_manual
