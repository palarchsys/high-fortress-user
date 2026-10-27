#!/usr/bin/env bash
# =============================================================================
# File       : service/postfix/configure.sh
# Updated at : 2026-10-27
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

if [[ "${HF_MAIL_ALERTS:-0}" != "1" ]]; then
    hf_log_info "Alertes e-mail coupées : Postfix n'est pas configuré."
    exit 0
fi

hf_log_title "Identifiants SMTP"
hf_log_info "Enregistrement de la carte SASL"
relay_host="${HF_POSTFIX_MAIL_SMTP%:*}"
relay_port="${HF_POSTFIX_MAIL_SMTP##*:}"
relayhost="[${relay_host}]:${relay_port}"
install -d -m 755 /etc/postfix
umask 077
printf '%s %s:%s\n' "${relayhost}" "${HF_POSTFIX_SMTP_LOGIN}" "${HF_POSTFIX_MAIL_PASSWORD}" \
    > /etc/postfix/sasl_passwd
umask 022
sasl_type="$(hf_get_sasl_map_type)"
case "${sasl_type}" in
    hash) sasl_index="/etc/postfix/sasl_passwd.db" ;;
    cdb) sasl_index="/etc/postfix/sasl_passwd.cdb" ;;
    lmdb) sasl_index="/etc/postfix/sasl_passwd.lmdb" ;;
esac
hf_run_silent postmap "${sasl_type}:/etc/postfix/sasl_passwd"
if [[ ! -f "${sasl_index}" ]]; then
    hf_log_error "Carte SASL absente après postmap."
fi
chmod 600 /etc/postfix/sasl_passwd "${sasl_index}"
hf_log_success "Carte SASL enregistrée (lecture root seulement)"

hf_log_title "Nom de courrier"
hf_log_info "Configuration du nom de courrier"
printf '%s\n' "$(hostname -f)" > /etc/mailname
chmod 644 /etc/mailname
hf_log_success "mailname enregistré ($(hostname -f))"

hf_log_title "Relais et réécriture de l'expéditeur"
hf_log_info "Configuration du relais et de l'expéditeur"
printf '/.*/ %s\n' "${HF_POSTFIX_MAIL_ADDRESS}" > /etc/postfix/sender_canonical
chmod 644 /etc/postfix/sender_canonical

hfu_apply_postfix() {
    local line key value host
    host="$(hostname -f)"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        value="${value//__HOSTNAME__/${host}}"
        value="${value//__RELAYHOST__/${relayhost}}"
        value="${value//__PROJECT_NAME__/${HF_PROJECT_NAME}}"
        value="${value//__SASL_TYPE__/${sasl_type}}"
        postconf -e "${key} = ${value}"
    done < "$(hf_locate_config_file postfix/main.keys)"
}
hfu_apply_postfix
hf_log_success "Expéditeur local réécrit, tout part comme ${HF_POSTFIX_MAIL_ADDRESS}"

hf_log_info "Redémarrage de Postfix"
hf_run_silent systemctl restart postfix
if ! systemctl is-active --quiet postfix; then
    hf_log_error "Postfix n'est pas actif après la configuration."
fi
hf_log_success "Postfix activé, écoute limitée à localhost"
