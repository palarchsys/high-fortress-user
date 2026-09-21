#!/usr/bin/env bash
# =============================================================================
# install.sh — amorçage High-Fortress User
# =============================================================================
# Dépôt privé : `curl | bash` sans jeton GitHub échouera. Préférer :
#
#   git clone git@github.com:palarchsys/high-fortress-user.git
#   cd high-fortress-user
#   sudo bash run.sh
#
# Avec jeton (HF_GITHUB_TOKEN ou GH_TOKEN) :
#   curl -fsSL -H "Authorization: Bearer $GH_TOKEN" \
#     https://raw.githubusercontent.com/palarchsys/high-fortress-user/main/install.sh \
#     | sudo bash
# =============================================================================

set -euo pipefail

REPO_URL="${HF_REPO_URL:-https://github.com/palarchsys/high-fortress-user}"
BRANCH="${HF_BRANCH:-main}"
INSTALL_ROOT="${HF_INSTALL_ROOT:-/opt/high-fortress-user/src}"
TOKEN="${HF_GITHUB_TOKEN:-${GH_TOKEN:-}}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Ce script doit être exécuté en root (sudo)." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates tar >/dev/null

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Téléchargement ${REPO_URL} (branche ${BRANCH})..."
auth_header=()
if [[ -n "${TOKEN}" ]]; then
    auth_header=(-H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json")
fi
if ! curl -fsSL "${auth_header[@]}" "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" -o "${tmp}/src.tar.gz"; then
    echo "Téléchargement impossible (dépôt privé ?). Clonez via SSH puis : sudo bash run.sh" >&2
    exit 1
fi
mkdir -p "${INSTALL_ROOT}"
tar -xzf "${tmp}/src.tar.gz" -C "${tmp}"
extracted="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d | head -1)"
if [[ -z "$extracted" ]]; then
    echo "Archive GitHub invalide." >&2
    exit 1
fi
rm -rf "${INSTALL_ROOT:?}"/*
cp -a "${extracted}/." "${INSTALL_ROOT}/"

export DEBUG_INSTALL_LOGS="${DEBUG_INSTALL_LOGS:-0}"

cd "${INSTALL_ROOT}"
exec bash "${INSTALL_ROOT}/run.sh"
