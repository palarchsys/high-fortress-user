#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root
g_get_current_user

g_log_title "Watchdogs cron (root, cron.allow non restreint)"

cpu_quota="$(
    G_WATCHDOG_CPU_LIMIT="${G_WATCHDOG_CPU_LIMIT:-50}" \
        bash -c 'source "$1" && g_get_cpu_quota_percent' _ "${G_INSTALL_DIRECTORY}/core/watchdog.sh"
)" || g_log_error "quota CPU introuvable"
[[ "${cpu_quota}" =~ ^[0-9]+$ ]] || g_log_error "quota CPU invalide (${cpu_quota:-vide})"
# shellcheck disable=SC1091
source "$(g_locate_config_file cron/timers.conf)"

g_log_info "Installation des watchdogs (chaîne au démarrage, passe horaire et analyse toutes les 2 h, plafonnée à ${G_WATCHDOG_CPU_LIMIT}% du CPU total)"
g_ensure_directory "${G_CONFIG_BASE_DIRECTORY}/cron/bin" 755
g_ensure_directory "${G_CONFIG_BASE_DIRECTORY}/cron/cron_logs" 750
g_ensure_directory "${G_CONFIG_BASE_DIRECTORY}/cron/security_logs" 750
g_ensure_directory "${G_CONFIG_BASE_DIRECTORY}/cron/alerts" 750

cp -a "${DIR_SCRIPT_PATH}/watchdogs/." "${G_CONFIG_BASE_DIRECTORY}/cron/bin/"
chmod 750 "${G_CONFIG_BASE_DIRECTORY}/cron/bin/"*.sh
g_source_core mail.sh
g_install_mail_templates "${G_CONFIG_BASE_DIRECTORY}/cron/bin"
mail_src="$(readlink -f "${G_INSTALL_DIRECTORY}/core/mail.sh")"
[[ -f "${mail_src}" ]] || g_log_error "core/mail.sh introuvable (${G_INSTALL_DIRECTORY}/core/mail.sh)"
cp -f "${mail_src}" "${G_CONFIG_BASE_DIRECTORY}/cron/bin/mail.sh"
chmod 750 "${G_CONFIG_BASE_DIRECTORY}/cron/bin/mail.sh"
watch_src="$(readlink -f "${G_INSTALL_DIRECTORY}/core/watchdog.sh")"
[[ -f "${watch_src}" ]] || g_log_error "core/watchdog.sh introuvable (${G_INSTALL_DIRECTORY}/core/watchdog.sh)"
cp -f "${watch_src}" "${G_CONFIG_BASE_DIRECTORY}/cron/bin/watchdog.sh"
chmod 750 "${G_CONFIG_BASE_DIRECTORY}/cron/bin/watchdog.sh"

umask 077
cat > "${G_CONFIG_BASE_DIRECTORY}/cron/mail.conf" << EOF
G_MAIL_ALERTS="${G_MAIL_ALERTS:-0}"
G_WATCHDOG_MAIL="${G_WATCHDOG_MAIL:-}"
G_PROJECT_NAME="${G_PROJECT_NAME}"
G_MAIL_TEMPLATE="${G_MAIL_TEMPLATE:-mail.html}"
G_RCLONE_ALERTS="${G_RCLONE_ALERTS:-0}"
G_RCLONE_REMOTE="${G_RCLONE_REMOTE:-gdrive}"
G_RCLONE_PATH="${G_RCLONE_PATH:-liltress-alerts}"
EOF
umask 022
chmod 600 "${G_CONFIG_BASE_DIRECTORY}/cron/mail.conf"
chown -R root:root "${G_CONFIG_BASE_DIRECTORY}/cron"
if [[ -f "${G_CONFIG_BASE_DIRECTORY}/cron/rclone.conf" ]]; then
    chown root:root "${G_CONFIG_BASE_DIRECTORY}/cron/rclone.conf"
    chmod 600 "${G_CONFIG_BASE_DIRECTORY}/cron/rclone.conf"
fi

export W_PROJECT_SLUG G_CONFIG_BASE_DIRECTORY

sed "s|\${G_CONFIG_BASE_DIRECTORY}|${G_CONFIG_BASE_DIRECTORY}|g" "$(g_locate_config_file cron/schedule.cron)" \
    > "/etc/cron.d/${W_PROJECT_SLUG}"
chown root:root "/etc/cron.d/${W_PROJECT_SLUG}"
chmod 600 "/etc/cron.d/${W_PROJECT_SLUG}"

install -d -m 755 /etc/systemd/system
systemctl_bin="$(command -v systemctl || true)"
[[ -n "${systemctl_bin}" ]] || g_log_error "systemctl introuvable"

w_render_unit() {
    local rel="$1"
    local src dest
    src="$(g_locate_config_file "cron/${rel}")" || g_log_error "unité absente : ${rel}"
    dest="/etc/systemd/system/${rel}"
    sed \
        -e "s|\\\${G_WATCHDOG_LIMIT_NICE}|${G_WATCHDOG_LIMIT_NICE}|g" \
        -e "s|\\\${cpu_quota}|${cpu_quota}|g" \
        -e "s|\\\${G_CONFIG_BASE_DIRECTORY}|${G_CONFIG_BASE_DIRECTORY}|g" \
        -e "s|\\\${systemctl_bin}|${systemctl_bin}|g" \
        -e "s|\\\${W_BOOT_ON_BOOT_SEC}|${W_BOOT_ON_BOOT_SEC}|g" \
        -e "s|\\\${W_BOOT_ACCURACY}|${W_BOOT_ACCURACY}|g" \
        -e "s|\\\${W_TIMER_PERSISTENT}|${W_TIMER_PERSISTENT}|g" \
        -e "s|\\\${W_IDLE_EVERY}|${W_IDLE_EVERY}|g" \
        -e "s|\\\${W_IDLE_ACCURACY}|${W_IDLE_ACCURACY}|g" \
        -e "s|\\\${W_REBOOT_EVERY}|${W_REBOOT_EVERY}|g" \
        -e "s|\\\${W_REBOOT_ACCURACY}|${W_REBOOT_ACCURACY}|g" \
        -e "s|\\\${W_PERIODIC_EVERY}|${W_PERIODIC_EVERY}|g" \
        -e "s|\\\${W_PERIODIC_ON_BOOT_SEC}|${W_PERIODIC_ON_BOOT_SEC}|g" \
        -e "s|\\\${W_PERIODIC_ACCURACY}|${W_PERIODIC_ACCURACY}|g" \
        -e "s|\\\${W_HOURLY_EVERY}|${W_HOURLY_EVERY}|g" \
        -e "s|\\\${W_HOURLY_ON_BOOT_SEC}|${W_HOURLY_ON_BOOT_SEC}|g" \
        -e "s|\\\${W_HOURLY_ACCURACY}|${W_HOURLY_ACCURACY}|g" \
        "${src}" > "${dest}"
    chmod 644 "${dest}"
}
w_render_unit w-boot-scan.service
w_render_unit w-boot-chain.service
w_render_unit w-boot-chain.timer
w_render_unit w-idle-scan.service
w_render_unit w-idle-scan.timer
w_render_unit w-reboot-notice.service
w_render_unit w-reboot-notice.timer
w_render_unit w-periodic-scan.service
w_render_unit w-periodic-scan.timer
w_render_unit w-hourly-scan.service
w_render_unit w-hourly-scan.timer
systemctl disable --now w-boot-scan.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/w-boot-scan.timer
systemctl disable --now w-integrity.timer >/dev/null 2>&1 || true
systemctl disable --now w-integrity.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/w-integrity.timer /etc/systemd/system/w-integrity.service
systemctl disable --now w-behavior.timer >/dev/null 2>&1 || true
systemctl disable --now w-behavior.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/w-behavior.timer /etc/systemd/system/w-behavior.service
systemctl disable --now w-egress-watch.timer >/dev/null 2>&1 || true
systemctl disable --now w-egress-watch.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/w-egress-watch.timer /etc/systemd/system/w-egress-watch.service
g_run_silent systemctl daemon-reload
g_run_silent systemctl enable w-boot-chain.timer
g_run_silent systemctl enable w-idle-scan.timer
g_run_silent systemctl enable w-reboot-notice.timer
g_run_silent systemctl enable w-periodic-scan.timer
g_run_silent systemctl enable w-hourly-scan.timer
g_log_success "Chaîne de démarrage, passe horaire et analyse toutes les 2 h installées, plafonnées à ${G_WATCHDOG_CPU_LIMIT}% du CPU total"

export W_BASE="${G_CONFIG_BASE_DIRECTORY}"
export W_SCAN_SKIP_HOME="${CURRENT_HOME}"
# shellcheck disable=SC1091
source "${DIR_SCRIPT_PATH}/watchdogs/scan-skip-lib.sh"
w_ensure_scan_skip_file "${CURRENT_HOME}"
if [[ ! -d /var/jeux ]]; then
    install -d -m 750 -o "${CURRENT_USER}" -g "${CURRENT_USER}" /var/jeux
fi
install -d -m 755 "${G_CONFIG_BASE_DIRECTORY}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/scan-skip.sh" "${G_CONFIG_BASE_DIRECTORY}/bin/scan-skip.sh"
install -m 755 "${DIR_SCRIPT_PATH}/boot-check.sh" "${G_CONFIG_BASE_DIRECTORY}/bin/boot-check.sh"
install -m 755 "$(readlink -f "${G_INSTALL_DIRECTORY}/core/quarantine-restore.sh")" \
    "${G_CONFIG_BASE_DIRECTORY}/bin/quarantine-restore.sh"
install -m 755 "$(readlink -f "${G_INSTALL_DIRECTORY}/core/mail-test.sh")" \
    "${G_CONFIG_BASE_DIRECTORY}/bin/mail-test.sh"
bash "${G_CONFIG_BASE_DIRECTORY}/cron/bin/apply-scan-skip.sh"

install -d -m 755 "${G_CONFIG_BASE_DIRECTORY}/config/integrity"
install -m 644 \
    "$(g_locate_config_file integrity/paths.list)" \
    "${G_CONFIG_BASE_DIRECTORY}/config/integrity/paths.list"
install -m 644 \
    "${G_INSTALL_DIRECTORY}/config/global.conf" \
    "${G_CONFIG_BASE_DIRECTORY}/config/global.conf"
export W_BASE="${G_CONFIG_BASE_DIRECTORY}"
g_run_silent bash "${G_CONFIG_BASE_DIRECTORY}/cron/bin/integrity.sh"

g_log_info "crontab utilisateur : non touché (pas de cron.allow)."
g_log_success "Watchdogs installés dans ${G_CONFIG_BASE_DIRECTORY}/cron/bin"
