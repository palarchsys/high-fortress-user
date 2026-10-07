#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/configure.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Watchdogs cron (root, cron.allow non restreint)"

info "Installation des watchdogs (démarrage plafonné à ${WATCHDOG_CPU_LIMIT}% CPU)"
ensure_dir "${CONFIG_BASE_DIR}/cron/bin" 755
ensure_dir "${CONFIG_BASE_DIR}/cron/cron_logs" 750
ensure_dir "${CONFIG_BASE_DIR}/cron/security_logs" 750
ensure_dir "${CONFIG_BASE_DIR}/cron/alerts" 750

cp -a "${DIR_SCRIPT_PATH}/watchdogs/." "${CONFIG_BASE_DIR}/cron/bin/"
chmod 750 "${CONFIG_BASE_DIR}/cron/bin/"*.sh
hf_source_core mail.sh
hf_install_mail_templates "${CONFIG_BASE_DIR}/cron/bin"
mail_src="$(readlink -f "${DIR_INSTALL_PATH}/core/mail.sh")"
[[ -f "${mail_src}" ]] || error "core/mail.sh introuvable (${DIR_INSTALL_PATH}/core/mail.sh)"
cp -f "${mail_src}" "${CONFIG_BASE_DIR}/cron/bin/mail.sh"
chmod 750 "${CONFIG_BASE_DIR}/cron/bin/mail.sh"

umask 077
cat > "${CONFIG_BASE_DIR}/cron/mail.conf" << EOF
HF_MAIL_ALERTS="${HF_MAIL_ALERTS:-0}"
WATCHDOG_MAIL="${WATCHDOG_MAIL:-}"
PROJECT_NAME="${PROJECT_NAME}"
MAIL_TEMPLATE="${MAIL_TEMPLATE:-mail.html}"
EOF
umask 022
chmod 600 "${CONFIG_BASE_DIR}/cron/mail.conf"
chown -R root:root "${CONFIG_BASE_DIR}/cron"

export PROJECT_SLUG CONFIG_BASE_DIR

sed "s|\${CONFIG_BASE_DIR}|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/hfu.cron" \
    > "/etc/cron.d/${PROJECT_SLUG}"
chown root:root "/etc/cron.d/${PROJECT_SLUG}"
chmod 600 "/etc/cron.d/${PROJECT_SLUG}"

install -d -m 755 /etc/systemd/system
tee /etc/systemd/system/hfu-boot-scan.service > /dev/null << EOF
[Unit]
Description=Passe AIDE, rkhunter, chkrootkit, ClamAV et debsums après le démarrage
After=local-fs.target multi-user.target
DefaultDependencies=no

[Service]
Type=oneshot
Nice=${WATCHDOG_LIMIT_NICE}
IOSchedulingClass=idle
CPUQuota=${WATCHDOG_CPU_LIMIT}%
ExecStart=${CONFIG_BASE_DIR}/cron/bin/boot-scan.sh
EOF
tee /etc/systemd/system/hfu-boot-scan.timer > /dev/null << 'EOF'
[Unit]
Description=Lance la passe de sécurité à chaque démarrage

[Timer]
OnBootSec=2min
AccuracySec=30s
Persistent=false
Unit=hfu-boot-scan.service

[Install]
WantedBy=timers.target
EOF
chmod 644 /etc/systemd/system/hfu-boot-scan.service /etc/systemd/system/hfu-boot-scan.timer
run_silent systemctl daemon-reload

run_silent systemctl enable hfu-boot-scan.timer
success "Démarrage plafonné à ${WATCHDOG_CPU_LIMIT}% CPU"

info "crontab utilisateur : non touché (pas de cron.allow)."
success "Watchdogs installés dans ${CONFIG_BASE_DIR}/cron/bin"
