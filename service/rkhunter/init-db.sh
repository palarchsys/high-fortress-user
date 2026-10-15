#!/usr/bin/env bash
# =============================================================================
# File       : service/rkhunter/init-db.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Base de référence rkhunter"
hf_log_info "Enregistrement de la base de référence rkhunter"
rk_out=""
rk_rc=0
rk_out=$(rkhunter --update --nocolors 2>&1) || rk_rc=$?
case "${rk_rc}" in
    0|2) ;;
    *) hf_log_warn "rkhunter --update rc=${rk_rc} (poursuivi) : ${rk_out}" ;;
esac

if [[ ( "${rk_rc}" -eq 0 || "${rk_rc}" -eq 2 ) && -x "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/record-mirrors.sh" ]]; then
    HFU_BASE="${HF_CONFIG_BASE_DIRECTORY}" bash "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/record-mirrors.sh" save || true
fi

hf_run_silent rkhunter --propupd
rk_tmp="/var/lib/rkhunter/tmp"
if [[ -d "${rk_tmp}" ]]; then
    cp -f -p /etc/passwd "${rk_tmp}/passwd"
    cp -f -p /etc/group "${rk_tmp}/group"
fi
hf_log_success "Baseline rkhunter enregistrée"
