#!/usr/bin/env bash
# =============================================================================
# File       : service/cron/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root
detect_current_user

title "Watchdogs cron (root, cron.allow non restreint)"

cpu_quota="$(
    WATCHDOG_CPU_LIMIT="${WATCHDOG_CPU_LIMIT:-50}" \
        bash -c 'source "$1" && hf_cpu_quota_percent' _ "${DIR_INSTALL_PATH}/core/watchdog.sh"
)" || error "quota CPU introuvable"
[[ "${cpu_quota}" =~ ^[0-9]+$ ]] || error "quota CPU invalide (${cpu_quota:-vide})"

info "Installation des watchdogs (chaîne au démarrage, plafonnée à ${WATCHDOG_CPU_LIMIT}% du CPU total)"
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
watch_src="$(readlink -f "${DIR_INSTALL_PATH}/core/watchdog.sh")"
[[ -f "${watch_src}" ]] || error "core/watchdog.sh introuvable (${DIR_INSTALL_PATH}/core/watchdog.sh)"
cp -f "${watch_src}" "${CONFIG_BASE_DIR}/cron/bin/watchdog.sh"
chmod 750 "${CONFIG_BASE_DIR}/cron/bin/watchdog.sh"

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
CPUQuota=${cpu_quota}%
ExecStart=${CONFIG_BASE_DIR}/cron/bin/boot-scan.sh
EOF
chmod 644 /etc/systemd/system/hfu-boot-scan.service
systemctl_bin="$(command -v systemctl || true)"
[[ -n "${systemctl_bin}" ]] || error "systemctl introuvable"
tee /etc/systemd/system/hfu-boot-chain.service > /dev/null << EOF
[Unit]
Description=Enchaîne la passe, l'analyse différée et l'avis de redémarrage
After=multi-user.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=-${systemctl_bin} start --wait hfu-boot-scan.service
ExecStart=-${systemctl_bin} start --wait hfu-idle-scan.service
ExecStart=-${systemctl_bin} start --wait hfu-reboot-notice.service
EOF
tee /etc/systemd/system/hfu-boot-chain.timer > /dev/null << 'EOF'
[Unit]
Description=Lance la chaîne de sécurité à chaque démarrage

[Timer]
OnBootSec=0
AccuracySec=1s
Persistent=false
Unit=hfu-boot-chain.service

[Install]
WantedBy=timers.target
EOF
chmod 644 /etc/systemd/system/hfu-boot-chain.service /etc/systemd/system/hfu-boot-chain.timer

tee /etc/systemd/system/hfu-idle-scan.service > /dev/null << EOF
[Unit]
Description=Analyse différée des chemins exclus du scan bloquant
After=local-fs.target multi-user.target

[Service]
Type=oneshot
Nice=${WATCHDOG_LIMIT_NICE}
IOSchedulingClass=idle
CPUQuota=${cpu_quota}%
ExecStart=${CONFIG_BASE_DIR}/cron/bin/idle-scan.sh
EOF
tee /etc/systemd/system/hfu-idle-scan.timer > /dev/null << 'EOF'
[Unit]
Description=Relance l'analyse différée des bibliothèques

[Timer]
OnUnitActiveSec=1h
AccuracySec=1min
Persistent=false
Unit=hfu-idle-scan.service

[Install]
WantedBy=timers.target
EOF
chmod 644 /etc/systemd/system/hfu-idle-scan.service /etc/systemd/system/hfu-idle-scan.timer

tee /etc/systemd/system/hfu-reboot-notice.service > /dev/null << EOF
[Unit]
Description=Avis lorsqu'un redémarrage est utile
After=local-fs.target multi-user.target

[Service]
Type=oneshot
Nice=${WATCHDOG_LIMIT_NICE}
IOSchedulingClass=idle
CPUQuota=${cpu_quota}%
ExecStart=${CONFIG_BASE_DIR}/cron/bin/reboot-notice.sh
EOF
tee /etc/systemd/system/hfu-reboot-notice.timer > /dev/null << 'EOF'
[Unit]
Description=Vérifie si un redémarrage est utile

[Timer]
OnUnitActiveSec=6h
AccuracySec=5min
Persistent=false
Unit=hfu-reboot-notice.service

[Install]
WantedBy=timers.target
EOF
chmod 644 /etc/systemd/system/hfu-reboot-notice.service /etc/systemd/system/hfu-reboot-notice.timer
systemctl disable --now hfu-boot-scan.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/hfu-boot-scan.timer
run_silent systemctl daemon-reload
run_silent systemctl enable hfu-boot-chain.timer
run_silent systemctl enable hfu-idle-scan.timer
run_silent systemctl enable hfu-reboot-notice.timer
success "Chaîne de démarrage installée, plafonnée à ${WATCHDOG_CPU_LIMIT}% du CPU total"

export HFU_BASE="${CONFIG_BASE_DIR}"
export HFU_SCAN_SKIP_HOME="${CURRENT_HOME}"
# shellcheck disable=SC1091
source "${DIR_SCRIPT_PATH}/watchdogs/scan-skip-lib.sh"
hfu_scan_skip_ensure_file "${CURRENT_HOME}"
if [[ ! -d /var/jeux ]]; then
    install -d -m 750 -o "${CURRENT_USER}" -g "${CURRENT_USER}" /var/jeux
fi
install -d -m 755 "${CONFIG_BASE_DIR}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/scan-skip.sh" "${CONFIG_BASE_DIR}/bin/scan-skip.sh"
install -m 755 "${DIR_SCRIPT_PATH}/boot-check.sh" "${CONFIG_BASE_DIR}/bin/boot-check.sh"
bash "${CONFIG_BASE_DIR}/cron/bin/apply-scan-skip.sh"

info "crontab utilisateur : non touché (pas de cron.allow)."
success "Watchdogs installés dans ${CONFIG_BASE_DIR}/cron/bin"
