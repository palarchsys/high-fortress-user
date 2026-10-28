#!/usr/bin/env bash
# =============================================================================
# File       : service/clamav/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
# shellcheck disable=SC1091
source "$(g_locate_config_file clamav/onaccess.conf)"
g_require_root

w_add_onaccess_directory() {
    local path="$1"
    [[ -n "${path}" && "${path}" != "/" && -d "${path}" ]] || return 0
    grep -qxF "OnAccessIncludePath ${path}" "${clam_conf}" && return 0
    printf 'OnAccessIncludePath %s\n' "${path}" >> "${clam_conf}"
}

w_remove_onaccess_directory() {
    local path="$1"
    [[ -n "${path}" && -f "${clam_conf}" ]] || return 0
    sed -i "\|^OnAccessIncludePath ${path}\$|d" "${clam_conf}"
}

w_ensure_xdg_directory() {
    local key="$1"
    local fallback="$2"
    local path
    path="$(sudo -u "${CURRENT_USER}" -H xdg-user-dir "${key}" 2>/dev/null || true)"
    [[ -n "${path}" && -d "${path}" ]] || path="${CURRENT_HOME}/${fallback}"
    install -d -m 755 -o "${CURRENT_USER}" -g "${CURRENT_USER}" "${path}"
    printf '%s\n' "${path}"
}

g_log_title "Configuration ClamAV"

g_log_info "Mise à jour des signatures (peut prendre 1–2 min)"

g_run_optional systemctl stop clamav-freshclam
fresh_log="${G_LOG_DIR:-/var/log/liltress-workstation}/freshclam.log"
mkdir -p "$(dirname "${fresh_log}")"
if freshclam --quiet >"${fresh_log}" 2>&1; then
    g_log_success "Signatures ClamAV mises à jour"
else
    g_log_warn "Freshclam incomplet, le service reprend"
fi
g_log_info "Activation de la surveillance ClamAV"
g_run_silent systemctl enable --now clamav-freshclam
g_run_silent systemctl enable --now clamav-daemon

g_get_current_user
install -d -m 755 "${G_CONFIG_BASE_DIRECTORY}/cron/bin"
install -m 755 \
    "${G_INSTALL_DIRECTORY}/service/cron/watchdogs/common.sh" \
    "${G_INSTALL_DIRECTORY}/service/cron/watchdogs/clamav-event.sh" \
    "${G_INSTALL_DIRECTORY}/service/cron/watchdogs/clamav-response.sh" \
    "${G_CONFIG_BASE_DIRECTORY}/cron/bin/"
rm -f "${G_CONFIG_BASE_DIRECTORY}/cron/clamav.conf"

download_dir="$(w_ensure_xdg_directory DOWNLOAD Downloads)"
desktop_dir="$(w_ensure_xdg_directory DESKTOP Desktop)"
documents_dir="$(w_ensure_xdg_directory DOCUMENTS Documents)"
music_dir="$(w_ensure_xdg_directory MUSIC Music)"
pictures_dir="$(w_ensure_xdg_directory PICTURES Pictures)"
videos_dir="$(w_ensure_xdg_directory VIDEOS Videos)"

event="${G_CONFIG_BASE_DIRECTORY}/cron/bin/clamav-event.sh"
clam_conf="/etc/clamav/clamd.conf"
if [[ -f "${clam_conf}" ]]; then
    if ! grep -q "${W_ONACCESS_MARKER}" "${clam_conf}" \
        && ! grep -q "High-Fortress User onaccess" "${clam_conf}"; then
        printf '\n# %s\n' "${W_ONACCESS_MARKER}" >> "${clam_conf}"
    fi
    w_add_onaccess_directory "${download_dir}"
    w_add_onaccess_directory "${desktop_dir}"
    w_add_onaccess_directory "${documents_dir}"
    w_add_onaccess_directory "${music_dir}"
    w_add_onaccess_directory "${pictures_dir}"
    w_add_onaccess_directory "${videos_dir}"
    w_add_onaccess_directory /tmp
    w_add_onaccess_directory /var/tmp
    w_add_onaccess_directory /opt
    if [[ "${W_ONACCESS_MOUNTS}" == "1" ]]; then
        w_add_onaccess_directory /media
        w_add_onaccess_directory /mnt
    else
        w_remove_onaccess_directory /media
        w_remove_onaccess_directory /mnt
    fi
    grep -qx "OnAccessExcludeUname ${W_ONACCESS_EXCLUDE_UNAME}" "${clam_conf}" \
        || printf 'OnAccessExcludeUname %s\n' "${W_ONACCESS_EXCLUDE_UNAME}" >> "${clam_conf}"
    grep -qx "OnAccessExcludeRootUID ${W_ONACCESS_EXCLUDE_ROOTUID}" "${clam_conf}" \
        || printf 'OnAccessExcludeRootUID %s\n' "${W_ONACCESS_EXCLUDE_ROOTUID}" >> "${clam_conf}"
    if grep -q '^OnAccessMaxFileSize ' "${clam_conf}"; then
        sed -i "s|^OnAccessMaxFileSize .*|OnAccessMaxFileSize ${W_ONACCESS_MAX_FILE_SIZE}|" "${clam_conf}"
    else
        printf 'OnAccessMaxFileSize %s\n' "${W_ONACCESS_MAX_FILE_SIZE}" >> "${clam_conf}"
    fi
    grep -qx "OnAccessPrevention ${W_ONACCESS_PREVENTION}" "${clam_conf}" \
        || printf 'OnAccessPrevention %s\n' "${W_ONACCESS_PREVENTION}" >> "${clam_conf}"
    grep -qx "OnAccessExtraScanning ${W_ONACCESS_EXTRA_SCANNING}" "${clam_conf}" \
        || printf 'OnAccessExtraScanning %s\n' "${W_ONACCESS_EXTRA_SCANNING}" >> "${clam_conf}"
    virus_line="VirusEvent sudo -n --preserve-env=${W_CLAMAV_VIRUS_EVENT_PRESERVE} ${event}"
    if grep -q '^VirusEvent ' "${clam_conf}"; then
        sed -i "s|^VirusEvent .*|${virus_line}|" "${clam_conf}"
    else
        printf '%s\n' "${virus_line}" >> "${clam_conf}"
    fi
    if ! grep -q '^TemporaryDirectory ' "${clam_conf}"; then
        printf 'TemporaryDirectory %s\n' "${W_CLAMAV_TEMPORARY_DIRECTORY}" >> "${clam_conf}"
    fi
fi

install -d -m 755 -o clamav -g clamav "${W_CLAMAV_TEMPORARY_DIRECTORY}"
tee /etc/sudoers.d/liltress-workstation-clamav > /dev/null << EOF
clamav ALL=(root) NOPASSWD: ${event}
EOF
chmod 440 /etc/sudoers.d/liltress-workstation-clamav
if ! visudo -cf /etc/sudoers.d/liltress-workstation-clamav >/dev/null; then
    rm -f /etc/sudoers.d/liltress-workstation-clamav
    g_log_error "sudoers ClamAV invalide"
fi

if id clamav >/dev/null 2>&1; then
    install -d -m 750 -o clamav -g clamav "${W_CLAMAV_QUARANTINE}"
else
    install -d -m 750 "${W_CLAMAV_QUARANTINE}"
fi

g_run_silent systemctl daemon-reload
g_run_optional systemctl unmask clamav-clamonacc.service clamonacc.service
clam_unit="clamav-clamonacc.service"
if ! systemctl cat "${clam_unit}" >/dev/null 2>&1; then
    clam_unit="clamonacc.service"
fi
if ! systemctl cat "${clam_unit}" >/dev/null 2>&1; then
    g_log_error "Unité clamonacc introuvable : la surveillance continue ne peut pas démarrer."
fi
install -d -m 755 "/etc/systemd/system/${clam_unit}.d"
tee "/etc/systemd/system/${clam_unit}.d/hfu.conf" > /dev/null << EOF
[Service]
ExecStart=
ExecStart=${W_CLAMONACC_BIN} -F --log=${W_CLAMONACC_LOG} --move=${W_CLAMAV_QUARANTINE}
Restart=${W_CLAMONACC_RESTART}
RestartSec=${W_CLAMONACC_RESTART_SEC}
EOF
g_run_silent systemctl daemon-reload

export W_BASE="${G_CONFIG_BASE_DIRECTORY}"
export W_SCAN_SKIP_HOME="${CURRENT_HOME}"
# shellcheck disable=SC1091
source "${G_INSTALL_DIRECTORY}/service/cron/watchdogs/scan-skip-lib.sh"
w_ensure_scan_skip_file "${CURRENT_HOME}"
bash "${G_INSTALL_DIRECTORY}/service/cron/watchdogs/apply-scan-skip.sh"
g_run_silent systemctl enable --now "${clam_unit}"
g_run_silent systemctl restart clamav-daemon
g_run_silent systemctl restart "${clam_unit}"

sleep 3
if ! systemctl is-active --quiet "${clam_unit}"; then
    journalctl -u "${clam_unit}" -n 40 --no-pager > "${G_LOG_DIR:-/var/log/liltress-workstation}/clamonacc.log" 2>&1 || true
    g_log_error "clamonacc ne reste pas actif. Détail : ${G_LOG_DIR:-/var/log/liltress-workstation}/clamonacc.log"
fi
zone_label="les dossiers utilisateur, /tmp, /var/tmp et /opt"
if [[ "${W_ONACCESS_MOUNTS}" == "1" ]]; then
    zone_label="${zone_label}, /media et /mnt"
fi
g_log_success "ClamAV lancé en surveillance continue sur ${zone_label}"
