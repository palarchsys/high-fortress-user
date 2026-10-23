#!/usr/bin/env bash
# =============================================================================
# File       : core/mail-test.sh
# Updated at : 2026-10-22
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Purpose    : Send one sample alert so the width and the height can be seen.
# Note       : The recipient stays in the installed configuration.
# -----------------------------------------------------------------------------

set -euo pipefail

hf_send_mail_test() {
    local script_dir base send_sh wide err_file
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$(basename -- "${script_dir}")" == "bin" ]]; then
        base="$(dirname -- "${script_dir}")"
    else
        base="${HF_CONFIG_BASE_DIRECTORY:-}"
    fi
    if [[ -z "${base}" || ! -f "${base}/config/global.conf" ]]; then
        printf '%s\n' "configuration absente" >&2
        exit 1
    fi
    export HF_INSTALL_DIRECTORY="${base}"
    export HF_CONFIG_BASE_DIRECTORY="${base}"
    # shellcheck disable=SC1091
    source "${base}/config/global.conf"
    if [[ -f "${base}/cron/mail.conf" ]]; then
        # shellcheck disable=SC1091
        source "${base}/cron/mail.conf"
    fi
    if [[ -f "${base}/cron/bin/watchdog.conf" ]]; then
        # shellcheck disable=SC1091
        source "${base}/cron/bin/watchdog.conf"
    fi
    if [[ -z "${HF_WATCHDOG_MAIL:-}" && -f "${base}/config/secrets.conf" ]]; then
        # shellcheck disable=SC1091
        source "${base}/config/secrets.conf"
    fi
    export HF_CONFIG_BASE_DIRECTORY="${base}"
    if [[ -z "${HF_PROJECT_NAME:-}" ]]; then
        HF_PROJECT_NAME="High-Fortress"
    fi
    export HF_PROJECT_NAME
    send_sh="${base}/cron/bin/send.sh"
    if [[ ! -f "${send_sh}" ]]; then
        printf '%s\n' "envoi introuvable" >&2
        exit 1
    fi
    if [[ "${HF_MAIL_ALERTS:-0}" != "1" ]]; then
        printf '%s\n' "alertes e-mail coupées" >&2
        exit 1
    fi
    if [[ -z "${HF_WATCHDOG_MAIL:-}" ]]; then
        printf '%s\n' "destinataire absent" >&2
        exit 1
    fi
    if ! command -v mail >/dev/null 2>&1; then
        printf '%s\n' "commande mail absente" >&2
        exit 1
    fi
    if [[ ! -f "${base}/cron/bin/${HF_MAIL_TEMPLATE:-mail.html}" ]]; then
        printf '%s\n' "modèle absent" >&2
        exit 1
    fi
    export HF_MAIL_TEMPLATE="${HF_MAIL_TEMPLATE:-mail.html}"
    export HF_MAIL_ALERTS
    export HF_WATCHDOG_MAIL
    export TITLE="Essai de mise en page"
    export MODULE_NAME="Essai"
    # One sample line is longer than the 800px floor.
    wide="$(printf 'X%.0s' {1..180})"
    export CONTENT="Ligne courte.
Cette ligne dépasse le minimum de 800px : ${wide}
Ligne courte."
    export NOTE="La largeur suit la ligne la plus longue. La hauteur occupe le volet."
    export NOTE_CMD="sudo bash ${base}/bin/mail-test.sh"
    err_file="$(mktemp)"
    if ! bash "${send_sh}" >/dev/null 2>"${err_file}"; then
        rm -f "${err_file}"
        printf '%s\n' "envoi refusé" >&2
        exit 1
    fi
    if grep -q 'Mail non envoyé' "${err_file}"; then
        rm -f "${err_file}"
        printf '%s\n' "envoi refusé" >&2
        exit 1
    fi
    rm -f "${err_file}"
    printf '%s\n' "message d'essai envoyé"
}

if [[ "${EUID}" -ne 0 ]]; then
    printf '%s\n' "root requis" >&2
    exit 1
fi

hf_send_mail_test
