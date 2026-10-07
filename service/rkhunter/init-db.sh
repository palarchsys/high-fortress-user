#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/init-db.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root

title "Base de référence rkhunter"
info "Enregistrement de la base de référence rkhunter"
rk_out=""
rk_rc=0
rk_out=$(rkhunter --update --nocolors 2>&1) || rk_rc=$?
case "${rk_rc}" in
    0|2) ;;
    *) warn "rkhunter --update rc=${rk_rc} (poursuivi) : ${rk_out}" ;;
esac

if [[ ( "${rk_rc}" -eq 0 || "${rk_rc}" -eq 2 ) && -x "${CONFIG_BASE_DIR}/cron/bin/record-mirrors.sh" ]]; then
    HFU_BASE="${CONFIG_BASE_DIR}" bash "${CONFIG_BASE_DIR}/cron/bin/record-mirrors.sh" save || true
fi

run_silent rkhunter --propupd
rk_tmp="/var/lib/rkhunter/tmp"
if [[ -d "${rk_tmp}" ]]; then
    cp -f -p /etc/passwd "${rk_tmp}/passwd"
    cp -f -p /etc/group "${rk_tmp}/group"
fi
success "Baseline rkhunter enregistrée"
