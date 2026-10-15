#!/usr/bin/env bash
# =============================================================================
# File       : service/clamav/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
# shellcheck disable=SC1091
source "$(hf_locate_config_file clamav/onaccess.conf)"
hf_require_root

hf_log_title "Configuration ClamAV"

hf_log_info "Mise à jour des signatures (peut prendre 1–2 min)"

hf_run_optional systemctl stop clamav-freshclam
fresh_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/freshclam.log"
mkdir -p "$(dirname "${fresh_log}")"
if freshclam --quiet >"${fresh_log}" 2>&1; then
    hf_log_success "Signatures ClamAV mises à jour"
else
    hf_log_warn "Freshclam incomplet, le service reprend"
fi
hf_log_info "Activation de la surveillance ClamAV"
hf_run_silent systemctl enable --now clamav-freshclam
hf_run_silent systemctl enable --now clamav-daemon

hf_get_current_user
install -d -m 755 "${HF_CONFIG_BASE_DIRECTORY}/cron/bin"
install -m 755 \
    "${HF_INSTALL_DIRECTORY}/service/cron/watchdogs/common.sh" \
    "${HF_INSTALL_DIRECTORY}/service/cron/watchdogs/clamav-event.sh" \
    "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/"
download_dir="$(sudo -u "${CURRENT_USER}" -H xdg-user-dir DOWNLOAD 2>/dev/null || true)"
desktop_dir="$(sudo -u "${CURRENT_USER}" -H xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -d "${download_dir}" ]] || download_dir="${CURRENT_HOME}/Downloads"
[[ -d "${desktop_dir}" ]] || desktop_dir="${CURRENT_HOME}/Desktop"
install -d -m 755 -o "${CURRENT_USER}" -g "${CURRENT_USER}" "${download_dir}" "${desktop_dir}"

event="${HF_CONFIG_BASE_DIRECTORY}/cron/bin/clamav-event.sh"
if [[ -f /etc/clamav/clamd.conf ]] && ! grep -q "${HFU_ONACCESS_MARKER}" /etc/clamav/clamd.conf; then
    if grep -q '^OnAccessIncludePath ' /etc/clamav/clamd.conf; then
        printf '\n# %s\n' "${HFU_ONACCESS_MARKER}" >> /etc/clamav/clamd.conf
    else
        cat >> /etc/clamav/clamd.conf << EOF

# ${HFU_ONACCESS_MARKER}
OnAccessIncludePath ${download_dir}
OnAccessIncludePath ${desktop_dir}
OnAccessExcludeUname ${HFU_ONACCESS_EXCLUDE_UNAME}
OnAccessExcludeRootUID ${HFU_ONACCESS_EXCLUDE_ROOTUID}
OnAccessMaxFileSize ${HFU_ONACCESS_MAX_FILE_SIZE}
OnAccessPrevention ${HFU_ONACCESS_PREVENTION}
OnAccessExtraScanning ${HFU_ONACCESS_EXTRA_SCANNING}
VirusEvent sudo -n --preserve-env=${HFU_CLAMAV_VIRUS_EVENT_PRESERVE} ${event}
EOF
    fi
fi

if [[ -f /etc/clamav/clamd.conf ]]; then
    sed -i '\|^OnAccessIncludePath /tmp$|d' /etc/clamav/clamd.conf
fi
clam_conf="/etc/clamav/clamd.conf"
if [[ -f "${clam_conf}" ]]; then
    grep -qx "OnAccessIncludePath ${download_dir}" "${clam_conf}" \
        || printf 'OnAccessIncludePath %s\n' "${download_dir}" >> "${clam_conf}"
    grep -qx "OnAccessIncludePath ${desktop_dir}" "${clam_conf}" \
        || printf 'OnAccessIncludePath %s\n' "${desktop_dir}" >> "${clam_conf}"
    grep -qx "OnAccessExcludeUname ${HFU_ONACCESS_EXCLUDE_UNAME}" "${clam_conf}" \
        || printf 'OnAccessExcludeUname %s\n' "${HFU_ONACCESS_EXCLUDE_UNAME}" >> "${clam_conf}"
    grep -qx "OnAccessExcludeRootUID ${HFU_ONACCESS_EXCLUDE_ROOTUID}" "${clam_conf}" \
        || printf 'OnAccessExcludeRootUID %s\n' "${HFU_ONACCESS_EXCLUDE_ROOTUID}" >> "${clam_conf}"
    if grep -q '^OnAccessMaxFileSize ' "${clam_conf}"; then
        sed -i "s|^OnAccessMaxFileSize .*|OnAccessMaxFileSize ${HFU_ONACCESS_MAX_FILE_SIZE}|" "${clam_conf}"
    else
        printf 'OnAccessMaxFileSize %s\n' "${HFU_ONACCESS_MAX_FILE_SIZE}" >> "${clam_conf}"
    fi
    grep -qx "OnAccessPrevention ${HFU_ONACCESS_PREVENTION}" "${clam_conf}" \
        || printf 'OnAccessPrevention %s\n' "${HFU_ONACCESS_PREVENTION}" >> "${clam_conf}"
    grep -qx "OnAccessExtraScanning ${HFU_ONACCESS_EXTRA_SCANNING}" "${clam_conf}" \
        || printf 'OnAccessExtraScanning %s\n' "${HFU_ONACCESS_EXTRA_SCANNING}" >> "${clam_conf}"
fi

install -d -m 755 -o clamav -g clamav "${HFU_CLAMAV_TEMPORARY_DIRECTORY}"
if [[ -f /etc/clamav/clamd.conf ]] && ! grep -q '^TemporaryDirectory ' /etc/clamav/clamd.conf; then
    printf 'TemporaryDirectory %s\n' "${HFU_CLAMAV_TEMPORARY_DIRECTORY}" >> /etc/clamav/clamd.conf
fi
tee /etc/sudoers.d/high-fortress-user-clamav > /dev/null << EOF
clamav ALL=(root) NOPASSWD: ${event}
EOF
chmod 440 /etc/sudoers.d/high-fortress-user-clamav
if ! visudo -cf /etc/sudoers.d/high-fortress-user-clamav >/dev/null; then
    rm -f /etc/sudoers.d/high-fortress-user-clamav
    hf_log_error "sudoers ClamAV invalide"
fi

if id clamav >/dev/null 2>&1; then
    install -d -m 750 -o clamav -g clamav "${HFU_CLAMAV_QUARANTINE}"
else
    install -d -m 750 "${HFU_CLAMAV_QUARANTINE}"
fi

hf_run_silent systemctl daemon-reload
hf_run_optional systemctl unmask clamav-clamonacc.service clamonacc.service
hf_run_silent systemctl restart clamav-daemon
clam_unit="clamav-clamonacc.service"
if ! systemctl cat "${clam_unit}" >/dev/null 2>&1; then
    clam_unit="clamonacc.service"
fi
if ! systemctl cat "${clam_unit}" >/dev/null 2>&1; then
    hf_log_error "Unité clamonacc introuvable : la surveillance continue ne peut pas démarrer."
fi
install -d -m 755 "/etc/systemd/system/${clam_unit}.d"
tee "/etc/systemd/system/${clam_unit}.d/hfu.conf" > /dev/null << EOF
[Service]
ExecStart=
ExecStart=${HFU_CLAMONACC_BIN} -F --log=${HFU_CLAMONACC_LOG} --move=${HFU_CLAMAV_QUARANTINE}
Restart=${HFU_CLAMONACC_RESTART}
RestartSec=${HFU_CLAMONACC_RESTART_SEC}
EOF
hf_run_silent systemctl daemon-reload
hf_run_silent systemctl enable --now "${clam_unit}"

sleep 3
if ! systemctl is-active --quiet "${clam_unit}"; then
    journalctl -u "${clam_unit}" -n 40 --no-pager > "${HF_LOG_DIR:-/var/log/high-fortress-user}/clamonacc.log" 2>&1 || true
    hf_log_error "clamonacc ne reste pas actif. Détail : ${HF_LOG_DIR:-/var/log/high-fortress-user}/clamonacc.log"
fi
export HFU_BASE="${HF_CONFIG_BASE_DIRECTORY}"
export HFU_SCAN_SKIP_HOME="${CURRENT_HOME}"
# shellcheck disable=SC1091
source "${HF_INSTALL_DIRECTORY}/service/cron/watchdogs/scan-skip-lib.sh"
hfu_ensure_scan_skip_file "${CURRENT_HOME}"
bash "${HF_INSTALL_DIRECTORY}/service/cron/watchdogs/apply-scan-skip.sh"
hf_log_success "ClamAV lancé en surveillance continue sur ${download_dir} et ${desktop_dir}"
