#!/usr/bin/env bash
# =============================================================================
# File       : install.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

set -euo pipefail

REPO_URL="${HF_REPO_URL:-https://github.com/palarchsys/high-fortress-user}"
BRANCH="${HF_BRANCH:-main}"

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
curl -fsSL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" -o "${tmp}/src.tar.gz"
mkdir -p "${tmp}/extract"
tar -xzf "${tmp}/src.tar.gz" -C "${tmp}/extract"
extracted="$(find "${tmp}/extract" -mindepth 1 -maxdepth 1 -type d | head -1)"
if [[ -z "${extracted}" || ! -f "${extracted}/global.conf" ]]; then
    echo "Archive GitHub invalide (global.conf absent)." >&2
    exit 1
fi

config_base="$(
    unset DIR_INSTALL_PATH
    set +u
    # shellcheck disable=SC1091
    source "${extracted}/global.conf"
    printf '%s\n' "${CONFIG_BASE_DIR}"
)"
if [[ -z "${config_base}" || "${config_base}" != /opt/* || "${config_base}" == *..* || "${config_base}" == *[[:space:]]* ]]; then
    echo "CONFIG_BASE_DIR invalide dans global.conf (${config_base:-vide})." >&2
    exit 1
fi
INSTALL_ROOT="${HF_INSTALL_ROOT:-${config_base}/src}"
if [[ "${INSTALL_ROOT}" != /* || "${INSTALL_ROOT}" == "/" || "${INSTALL_ROOT}" == *..* || "${INSTALL_ROOT}" == *[[:space:]]* ]]; then
    echo "Racine d'install refusée : ${INSTALL_ROOT}" >&2
    exit 1
fi

mkdir -p "${INSTALL_ROOT}"
keep=""
if [[ -f "${INSTALL_ROOT}/global.conf" ]] && grep -q '^HF_PREPARED=1$' "${INSTALL_ROOT}/global.conf" && [[ -f "${INSTALL_ROOT}/secrets.conf" ]]; then
    mkdir -p "${tmp}/keep"
    cp -a "${INSTALL_ROOT}/global.conf" "${INSTALL_ROOT}/secrets.conf" "${tmp}/keep/"
    keep=1
fi
rm -rf "${INSTALL_ROOT:?}"/*
cp -a "${extracted}/." "${INSTALL_ROOT}/"
if [[ "${keep}" == "1" ]]; then
    cp -a "${tmp}/keep/global.conf" "${tmp}/keep/secrets.conf" "${INSTALL_ROOT}/"
    chmod 600 "${INSTALL_ROOT}/secrets.conf" || true
fi
if [[ ! -f "${INSTALL_ROOT}/hf" ]]; then
    printf 'hf absent après extraction.\n' >&2
    exit 1
fi
chmod 755 "${INSTALL_ROOT}/hf"

if [[ "${keep}" != "1" ]]; then
    printf '\nTéléchargement terminé. Les sources sont dans %s.\n' "${INSTALL_ROOT}"
    printf 'Lancement de la configuration.\n\n'
    exec bash "${INSTALL_ROOT}/scripts/configure.sh"
fi

if ! bash "${INSTALL_ROOT}/scripts/configure.sh" --check; then
    printf '\nLa configuration enregistrée ne passe plus le contrôle.\n' >&2
    printf 'Lancement des questions.\n\n' >&2
    exec bash "${INSTALL_ROOT}/scripts/configure.sh"
fi

cd "${INSTALL_ROOT}"
exec bash "${INSTALL_ROOT}/scripts/run.sh"
