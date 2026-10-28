#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/init-db.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

g_log_title "Base de référence rkhunter"
g_log_info "Enregistrement de la base de référence rkhunter"
rk_out=""
rk_rc=0
rk_out=$(rkhunter --update --nocolors 2>&1) || rk_rc=$?
case "${rk_rc}" in
    0|2) ;;
    *) g_log_warn "rkhunter --update rc=${rk_rc} (poursuivi) : ${rk_out}" ;;
esac

if [[ ( "${rk_rc}" -eq 0 || "${rk_rc}" -eq 2 ) && -x "${G_CONFIG_BASE_DIRECTORY}/cron/bin/record-mirrors.sh" ]]; then
    W_BASE="${G_CONFIG_BASE_DIRECTORY}" bash "${G_CONFIG_BASE_DIRECTORY}/cron/bin/record-mirrors.sh" save || true
fi

g_run_silent rkhunter --propupd
rk_tmp="/var/lib/rkhunter/tmp"
if [[ -d "${rk_tmp}" ]]; then
    cp -f -p /etc/passwd "${rk_tmp}/passwd"
    cp -f -p /etc/group "${rk_tmp}/group"
fi
g_log_success "Baseline rkhunter enregistrée"
