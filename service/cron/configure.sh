#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/cron/configure.sh
# Créé le    : 2026-09-21
# Créateur   : palarchsys
#
# Rôle
#   service/cron/configure.sh
# =============================================================================

# Watchdogs en root via /etc/cron.d. PAS de cron.allow restrictif
# (l'utilisateur desktop garde crontab). PAS d'utilisateur cronexecutor.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

title "Watchdogs cron (root, cron.allow non restreint)"

ensure_dir "${CONFIG_BASE_DIR}/cron/bin" 755
ensure_dir "${CONFIG_BASE_DIR}/cron/cron_logs" 750
ensure_dir "${CONFIG_BASE_DIR}/cron/security_logs" 750
ensure_dir "${CONFIG_BASE_DIR}/cron/alerts" 750

cp -a "${DIR_SCRIPT_PATH}/watchdogs/." "${CONFIG_BASE_DIR}/cron/bin/"
chmod 750 "${CONFIG_BASE_DIR}/cron/bin/"*.sh
chmod 644 "${CONFIG_BASE_DIR}/cron/bin/mail.html"
# Destinataire des alertes, sans le mot de passe SMTP.
umask 077
cat > "${CONFIG_BASE_DIR}/cron/mail.conf" << EOF
WATCHDOG_MAIL="${WATCHDOG_MAIL}"
PROJECT_NAME="${PROJECT_NAME}"
EOF
umask 022
chmod 600 "${CONFIG_BASE_DIR}/cron/mail.conf"
chown -R root:root "${CONFIG_BASE_DIR}/cron"

export PROJECT_SLUG CONFIG_BASE_DIR
# envsubst the cron file
sed "s|\${CONFIG_BASE_DIR}|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/hfu.cron" \
    > "/etc/cron.d/${PROJECT_SLUG}"
chown root:root "/etc/cron.d/${PROJECT_SLUG}"
chmod 600 "/etc/cron.d/${PROJECT_SLUG}"

# Les contrôles se suivent. Le plafond reste 20 % pour toute la passe,
# sans le multiplier par le nombre de cœurs.
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
# enable sans démarrage immédiat : la passe part au prochain démarrage,
# deux minutes après l'arrivée du système, sans bloquer l'ouverture de session.
run_silent systemctl enable hfu-boot-scan.timer
success "Passe au démarrage plafonnée à ${WATCHDOG_CPU_LIMIT} % du processeur (CPUQuota=${WATCHDOG_CPU_LIMIT}%)"

info "crontab utilisateur : non touché (pas de cron.allow)."
success "Watchdogs installés dans ${CONFIG_BASE_DIR}/cron/bin"
