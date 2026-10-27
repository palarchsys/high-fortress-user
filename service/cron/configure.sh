#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/configure.sh
# Updated at : 2026-10-22
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
hf_get_current_user

hf_log_title "Watchdogs cron (root, cron.allow non restreint)"

cpu_quota="$(
    HF_WATCHDOG_CPU_LIMIT="${HF_WATCHDOG_CPU_LIMIT:-50}" \
        bash -c 'source "$1" && hf_get_cpu_quota_percent' _ "${HF_INSTALL_DIRECTORY}/core/watchdog.sh"
)" || hf_log_error "quota CPU introuvable"
[[ "${cpu_quota}" =~ ^[0-9]+$ ]] || hf_log_error "quota CPU invalide (${cpu_quota:-vide})"
# shellcheck disable=SC1091
source "$(hf_locate_config_file cron/timers.conf)"

hf_log_info "Installation des watchdogs (chaîne au démarrage, passe horaire et analyse toutes les 2 h, plafonnée à ${HF_WATCHDOG_CPU_LIMIT}% du CPU total)"
hf_ensure_directory "${HF_CONFIG_BASE_DIRECTORY}/cron/bin" 755
hf_ensure_directory "${HF_CONFIG_BASE_DIRECTORY}/cron/cron_logs" 750
hf_ensure_directory "${HF_CONFIG_BASE_DIRECTORY}/cron/security_logs" 750
hf_ensure_directory "${HF_CONFIG_BASE_DIRECTORY}/cron/alerts" 750

cp -a "${DIR_SCRIPT_PATH}/watchdogs/." "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/"
chmod 750 "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/"*.sh
hf_source_core mail.sh
hf_install_mail_templates "${HF_CONFIG_BASE_DIRECTORY}/cron/bin"
mail_src="$(readlink -f "${HF_INSTALL_DIRECTORY}/core/mail.sh")"
[[ -f "${mail_src}" ]] || hf_log_error "core/mail.sh introuvable (${HF_INSTALL_DIRECTORY}/core/mail.sh)"
cp -f "${mail_src}" "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/mail.sh"
chmod 750 "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/mail.sh"
watch_src="$(readlink -f "${HF_INSTALL_DIRECTORY}/core/watchdog.sh")"
[[ -f "${watch_src}" ]] || hf_log_error "core/watchdog.sh introuvable (${HF_INSTALL_DIRECTORY}/core/watchdog.sh)"
cp -f "${watch_src}" "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/watchdog.sh"
chmod 750 "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/watchdog.sh"

umask 077
cat > "${HF_CONFIG_BASE_DIRECTORY}/cron/mail.conf" << EOF
HF_MAIL_ALERTS="${HF_MAIL_ALERTS:-0}"
HF_WATCHDOG_MAIL="${HF_WATCHDOG_MAIL:-}"
HF_PROJECT_NAME="${HF_PROJECT_NAME}"
HF_MAIL_TEMPLATE="${HF_MAIL_TEMPLATE:-mail.html}"
HF_RCLONE_ALERTS="${HF_RCLONE_ALERTS:-0}"
HF_RCLONE_REMOTE="${HF_RCLONE_REMOTE:-gdrive}"
HF_RCLONE_PATH="${HF_RCLONE_PATH:-high-fortress-alerts}"
EOF
umask 022
chmod 600 "${HF_CONFIG_BASE_DIRECTORY}/cron/mail.conf"
chown -R root:root "${HF_CONFIG_BASE_DIRECTORY}/cron"
if [[ -f "${HF_CONFIG_BASE_DIRECTORY}/cron/rclone.conf" ]]; then
    chown root:root "${HF_CONFIG_BASE_DIRECTORY}/cron/rclone.conf"
    chmod 600 "${HF_CONFIG_BASE_DIRECTORY}/cron/rclone.conf"
fi

export HFU_PROJECT_SLUG HF_CONFIG_BASE_DIRECTORY

sed "s|\${HF_CONFIG_BASE_DIRECTORY}|${HF_CONFIG_BASE_DIRECTORY}|g" "$(hf_locate_config_file cron/schedule.cron)" \
    > "/etc/cron.d/${HFU_PROJECT_SLUG}"
chown root:root "/etc/cron.d/${HFU_PROJECT_SLUG}"
chmod 600 "/etc/cron.d/${HFU_PROJECT_SLUG}"

install -d -m 755 /etc/systemd/system
systemctl_bin="$(command -v systemctl || true)"
[[ -n "${systemctl_bin}" ]] || hf_log_error "systemctl introuvable"

hfu_render_unit() {
    local rel="$1"
    local src dest
    src="$(hf_locate_config_file "cron/${rel}")" || hf_log_error "unité absente : ${rel}"
    dest="/etc/systemd/system/${rel}"
    sed \
        -e "s|\\\${HF_WATCHDOG_LIMIT_NICE}|${HF_WATCHDOG_LIMIT_NICE}|g" \
        -e "s|\\\${cpu_quota}|${cpu_quota}|g" \
        -e "s|\\\${HF_CONFIG_BASE_DIRECTORY}|${HF_CONFIG_BASE_DIRECTORY}|g" \
        -e "s|\\\${systemctl_bin}|${systemctl_bin}|g" \
        -e "s|\\\${HFU_BOOT_ON_BOOT_SEC}|${HFU_BOOT_ON_BOOT_SEC}|g" \
        -e "s|\\\${HFU_BOOT_ACCURACY}|${HFU_BOOT_ACCURACY}|g" \
        -e "s|\\\${HFU_TIMER_PERSISTENT}|${HFU_TIMER_PERSISTENT}|g" \
        -e "s|\\\${HFU_IDLE_EVERY}|${HFU_IDLE_EVERY}|g" \
        -e "s|\\\${HFU_IDLE_ACCURACY}|${HFU_IDLE_ACCURACY}|g" \
        -e "s|\\\${HFU_REBOOT_EVERY}|${HFU_REBOOT_EVERY}|g" \
        -e "s|\\\${HFU_REBOOT_ACCURACY}|${HFU_REBOOT_ACCURACY}|g" \
        -e "s|\\\${HFU_PERIODIC_EVERY}|${HFU_PERIODIC_EVERY}|g" \
        -e "s|\\\${HFU_PERIODIC_ON_BOOT_SEC}|${HFU_PERIODIC_ON_BOOT_SEC}|g" \
        -e "s|\\\${HFU_PERIODIC_ACCURACY}|${HFU_PERIODIC_ACCURACY}|g" \
        -e "s|\\\${HFU_HOURLY_EVERY}|${HFU_HOURLY_EVERY}|g" \
        -e "s|\\\${HFU_HOURLY_ON_BOOT_SEC}|${HFU_HOURLY_ON_BOOT_SEC}|g" \
        -e "s|\\\${HFU_HOURLY_ACCURACY}|${HFU_HOURLY_ACCURACY}|g" \
        "${src}" > "${dest}"
    chmod 644 "${dest}"
}
hfu_render_unit hfu-boot-scan.service
hfu_render_unit hfu-boot-chain.service
hfu_render_unit hfu-boot-chain.timer
hfu_render_unit hfu-idle-scan.service
hfu_render_unit hfu-idle-scan.timer
hfu_render_unit hfu-reboot-notice.service
hfu_render_unit hfu-reboot-notice.timer
hfu_render_unit hfu-periodic-scan.service
hfu_render_unit hfu-periodic-scan.timer
hfu_render_unit hfu-hourly-scan.service
hfu_render_unit hfu-hourly-scan.timer
systemctl disable --now hfu-boot-scan.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/hfu-boot-scan.timer
systemctl disable --now hfu-integrity.timer >/dev/null 2>&1 || true
systemctl disable --now hfu-integrity.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/hfu-integrity.timer /etc/systemd/system/hfu-integrity.service
systemctl disable --now hfu-behavior.timer >/dev/null 2>&1 || true
systemctl disable --now hfu-behavior.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/hfu-behavior.timer /etc/systemd/system/hfu-behavior.service
systemctl disable --now hfu-egress-watch.timer >/dev/null 2>&1 || true
systemctl disable --now hfu-egress-watch.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/hfu-egress-watch.timer /etc/systemd/system/hfu-egress-watch.service
hf_run_silent systemctl daemon-reload
hf_run_silent systemctl enable hfu-boot-chain.timer
hf_run_silent systemctl enable hfu-idle-scan.timer
hf_run_silent systemctl enable hfu-reboot-notice.timer
hf_run_silent systemctl enable hfu-periodic-scan.timer
hf_run_silent systemctl enable hfu-hourly-scan.timer
hf_log_success "Chaîne de démarrage, passe horaire et analyse toutes les 2 h installées, plafonnées à ${HF_WATCHDOG_CPU_LIMIT}% du CPU total"

export HFU_BASE="${HF_CONFIG_BASE_DIRECTORY}"
export HFU_SCAN_SKIP_HOME="${CURRENT_HOME}"
# shellcheck disable=SC1091
source "${DIR_SCRIPT_PATH}/watchdogs/scan-skip-lib.sh"
hfu_ensure_scan_skip_file "${CURRENT_HOME}"
if [[ ! -d /var/jeux ]]; then
    install -d -m 750 -o "${CURRENT_USER}" -g "${CURRENT_USER}" /var/jeux
fi
install -d -m 755 "${HF_CONFIG_BASE_DIRECTORY}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/scan-skip.sh" "${HF_CONFIG_BASE_DIRECTORY}/bin/scan-skip.sh"
install -m 755 "${DIR_SCRIPT_PATH}/boot-check.sh" "${HF_CONFIG_BASE_DIRECTORY}/bin/boot-check.sh"
install -m 755 "$(readlink -f "${HF_INSTALL_DIRECTORY}/core/quarantine-restore.sh")" \
    "${HF_CONFIG_BASE_DIRECTORY}/bin/quarantine-restore.sh"
install -m 755 "$(readlink -f "${HF_INSTALL_DIRECTORY}/core/mail-test.sh")" \
    "${HF_CONFIG_BASE_DIRECTORY}/bin/mail-test.sh"
bash "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/apply-scan-skip.sh"

install -d -m 755 "${HF_CONFIG_BASE_DIRECTORY}/config/integrity"
install -m 644 \
    "$(hf_locate_config_file integrity/paths.list)" \
    "${HF_CONFIG_BASE_DIRECTORY}/config/integrity/paths.list"
install -m 644 \
    "${HF_INSTALL_DIRECTORY}/config/global.conf" \
    "${HF_CONFIG_BASE_DIRECTORY}/config/global.conf"
export HFU_BASE="${HF_CONFIG_BASE_DIRECTORY}"
hf_run_silent bash "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/integrity.sh"

hf_log_info "crontab utilisateur : non touché (pas de cron.allow)."
hf_log_success "Watchdogs installés dans ${HF_CONFIG_BASE_DIRECTORY}/cron/bin"
