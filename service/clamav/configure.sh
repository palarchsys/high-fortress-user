#!/usr/bin/env bash
# =============================================================================
# File       : service/clamav/configure.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Configuration ClamAV"

info "Mise à jour des signatures (peut prendre 1–2 min)"

try_silent systemctl stop clamav-freshclam
fresh_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/freshclam.log"
mkdir -p "$(dirname "${fresh_log}")"
if freshclam --quiet >"${fresh_log}" 2>&1; then
    success "Signatures ClamAV mises à jour"
else
    warn "Freshclam incomplet, le service reprend"
fi
info "Activation de la surveillance ClamAV"
run_silent systemctl enable --now clamav-freshclam
run_silent systemctl enable --now clamav-daemon

detect_current_user
install -d -m 755 "${CONFIG_BASE_DIR}/cron/bin"
install -m 755 \
    "${DIR_INSTALL_PATH}/service/cron/watchdogs/common.sh" \
    "${DIR_INSTALL_PATH}/service/cron/watchdogs/clamav-event.sh" \
    "${CONFIG_BASE_DIR}/cron/bin/"
download_dir="$(sudo -u "${CURRENT_USER}" -H xdg-user-dir DOWNLOAD 2>/dev/null || true)"
desktop_dir="$(sudo -u "${CURRENT_USER}" -H xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -d "${download_dir}" ]] || download_dir="${CURRENT_HOME}/Downloads"
[[ -d "${desktop_dir}" ]] || desktop_dir="${CURRENT_HOME}/Desktop"
install -d -m 755 -o "${CURRENT_USER}" -g "${CURRENT_USER}" "${download_dir}" "${desktop_dir}"

event="${CONFIG_BASE_DIR}/cron/bin/clamav-event.sh"
if [[ -f /etc/clamav/clamd.conf ]] && ! grep -q 'High-Fortress User onaccess' /etc/clamav/clamd.conf; then
    cat >> /etc/clamav/clamd.conf << EOF

OnAccessIncludePath ${download_dir}
OnAccessIncludePath ${desktop_dir}
OnAccessExcludePath ${CURRENT_HOME}/.steam
OnAccessExcludePath ${CURRENT_HOME}/.local/share/Steam
OnAccessExcludeUname clamav
OnAccessExcludeRootUID yes
OnAccessMaxFileSize 25M
OnAccessPrevention yes
OnAccessExtraScanning yes
VirusEvent sudo -n --preserve-env=CLAM_VIRUSEVENT_FILENAME,CLAM_VIRUSEVENT_VIRUSNAME ${event}
EOF
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
    grep -qx 'OnAccessExcludeUname clamav' "${clam_conf}" \
        || printf '%s\n' 'OnAccessExcludeUname clamav' >> "${clam_conf}"
    grep -qx 'OnAccessExcludeRootUID yes' "${clam_conf}" \
        || printf '%s\n' 'OnAccessExcludeRootUID yes' >> "${clam_conf}"
    if grep -q '^OnAccessMaxFileSize ' "${clam_conf}"; then
        sed -i 's/^OnAccessMaxFileSize .*/OnAccessMaxFileSize 25M/' "${clam_conf}"
    else
        printf '%s\n' 'OnAccessMaxFileSize 25M' >> "${clam_conf}"
    fi
    grep -qx 'OnAccessPrevention yes' "${clam_conf}" \
        || printf '%s\n' 'OnAccessPrevention yes' >> "${clam_conf}"
    grep -qx 'OnAccessExtraScanning yes' "${clam_conf}" \
        || printf '%s\n' 'OnAccessExtraScanning yes' >> "${clam_conf}"
fi

install -d -m 755 -o clamav -g clamav /var/lib/clamav/tmp
if [[ -f /etc/clamav/clamd.conf ]] && ! grep -q '^TemporaryDirectory ' /etc/clamav/clamd.conf; then
    printf '%s\n' 'TemporaryDirectory /var/lib/clamav/tmp' >> /etc/clamav/clamd.conf
fi
tee /etc/sudoers.d/high-fortress-user-clamav > /dev/null << EOF
clamav ALL=(root) NOPASSWD: ${event}
EOF
chmod 440 /etc/sudoers.d/high-fortress-user-clamav
if ! visudo -cf /etc/sudoers.d/high-fortress-user-clamav >/dev/null; then
    rm -f /etc/sudoers.d/high-fortress-user-clamav
    error "sudoers ClamAV invalide"
fi

if id clamav >/dev/null 2>&1; then
    install -d -m 750 -o clamav -g clamav /var/lib/clamav/quarantine
else
    install -d -m 750 /var/lib/clamav/quarantine
fi

run_silent systemctl daemon-reload
try_silent systemctl unmask clamav-clamonacc.service clamonacc.service
run_silent systemctl restart clamav-daemon
clam_unit="clamav-clamonacc.service"
if ! systemctl cat "${clam_unit}" >/dev/null 2>&1; then
    clam_unit="clamonacc.service"
fi
if ! systemctl cat "${clam_unit}" >/dev/null 2>&1; then
    error "Unité clamonacc introuvable : la surveillance continue ne peut pas démarrer."
fi
install -d -m 755 "/etc/systemd/system/${clam_unit}.d"
tee "/etc/systemd/system/${clam_unit}.d/hfu.conf" > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/sbin/clamonacc -F --log=/var/log/clamav/clamonacc.log --move=/var/lib/clamav/quarantine
Restart=on-failure
RestartSec=5
EOF
run_silent systemctl daemon-reload
run_silent systemctl enable --now "${clam_unit}"

sleep 3
if ! systemctl is-active --quiet "${clam_unit}"; then
    journalctl -u "${clam_unit}" -n 40 --no-pager > "${HF_LOG_DIR:-/var/log/high-fortress-user}/clamonacc.log" 2>&1 || true
    error "clamonacc ne reste pas actif. Détail : ${HF_LOG_DIR:-/var/log/high-fortress-user}/clamonacc.log"
fi
success "ClamAV lancé en surveillance continue sur ${download_dir} et ${desktop_dir}"
