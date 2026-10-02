#!/usr/bin/env bash

# Suite 03 — fonctions conservées.

hf_section "fonctions conservées"
MONO="$(cd -- "${HF_ROOT}/.." && pwd)"

need_fn() {
    local name="$1"
    local where="$2"
    if grep -RInE "^${name}[[:space:]]*\\(\\)" ${where} >/dev/null 2>&1; then
        hf_pass "fn:${name}" "présente"
    else
        hf_fail "fn:${name}" "absente de ${where}"
    fi
}

for name in blue require_root step_on error run_silent try_silent run_silent_apt run_steps \
    add_line_if_missing backup_file_once ensure_dir user_exists init_install_log \
    collect_install_logs hf_publish_repo_logs hf_debug_logs_enabled; do
    need_fn "${name}" "${MONO}/core"
done
for name in detect_current_user detect_os hfu_is_desktop_account write_human_account_table \
    snapshot_human_accounts hfu_strip_virt_groups human_accounts_drift detect_ssh_port \
    virt_present app_present assert_no_password_mutation ubuntu_pro_attached \
    hfu_collect_product_logs; do
    need_fn "${name}" "${HF_ROOT}/core/lib.sh"
done
for name in hfu_is_email hfu_is_port hfu_is_smtp hfu_is_abs_path hfu_is_secret hf_is_app_password; do
    need_fn "${name}" "${MONO}/core/config-validators.sh"
done
need_fn hfu_is_pro_token "${HF_ROOT}/scripts/config-check.sh"
need_fn assert_localhost_port_free "${MONO}/server/core/lib.sh"
need_fn hf_render_mail "${MONO}/core/mail.sh"
need_fn hf_install_mail_templates "${MONO}/core/mail.sh"
