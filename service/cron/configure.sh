#!/usr/bin/env bash
# =============================================================================
# service/cron/configure.sh
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
chown -R root:root "${CONFIG_BASE_DIR}/cron"

export PROJECT_SLUG CONFIG_BASE_DIR
# envsubst the cron file
sed "s|\${CONFIG_BASE_DIR}|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/hfu.cron" \
    > "/etc/cron.d/${PROJECT_SLUG}"
chown root:root "/etc/cron.d/${PROJECT_SLUG}"
chmod 600 "/etc/cron.d/${PROJECT_SLUG}"

info "crontab utilisateur : non touché (pas de cron.allow)."
success "Watchdogs installés dans ${CONFIG_BASE_DIR}/cron/bin"
