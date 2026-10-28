#!/usr/bin/env bash
# =============================================================================
# File       : service/postfix/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root

if [[ "${G_MAIL_ALERTS:-0}" != "1" ]]; then
    g_log_info "Alertes e-mail coupées : Postfix n'est pas configuré."
    exit 0
fi

g_log_title "Identifiants SMTP"
g_log_info "Enregistrement de la carte SASL"
relay_host="${G_POSTFIX_MAIL_SMTP%:*}"
relay_port="${G_POSTFIX_MAIL_SMTP##*:}"
relayhost="[${relay_host}]:${relay_port}"
install -d -m 755 /etc/postfix
umask 077
printf '%s %s:%s\n' "${relayhost}" "${G_POSTFIX_SMTP_LOGIN}" "${G_POSTFIX_MAIL_PASSWORD}" \
    > /etc/postfix/sasl_passwd
umask 022
sasl_type="$(g_get_sasl_map_type)"
case "${sasl_type}" in
    hash) sasl_index="/etc/postfix/sasl_passwd.db" ;;
    cdb) sasl_index="/etc/postfix/sasl_passwd.cdb" ;;
    lmdb) sasl_index="/etc/postfix/sasl_passwd.lmdb" ;;
esac
g_run_silent postmap "${sasl_type}:/etc/postfix/sasl_passwd"
if [[ ! -f "${sasl_index}" ]]; then
    g_log_error "Carte SASL absente après postmap."
fi
chmod 600 /etc/postfix/sasl_passwd "${sasl_index}"
g_log_success "Carte SASL enregistrée (lecture root seulement)"

g_log_title "Nom de courrier"
g_log_info "Configuration du nom de courrier"
printf '%s\n' "$(hostname -f)" > /etc/mailname
chmod 644 /etc/mailname
g_log_success "mailname enregistré ($(hostname -f))"

g_log_title "Relais et réécriture de l'expéditeur"
g_log_info "Configuration du relais et de l'expéditeur"
printf '/.*/ %s\n' "${G_POSTFIX_MAIL_ADDRESS}" > /etc/postfix/sender_canonical
chmod 644 /etc/postfix/sender_canonical

w_apply_postfix() {
    local line key value host
    host="$(hostname -f)"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        value="${value//__HOSTNAME__/${host}}"
        value="${value//__RELAYHOST__/${relayhost}}"
        value="${value//__PROJECT_NAME__/${G_PROJECT_NAME}}"
        value="${value//__SASL_TYPE__/${sasl_type}}"
        postconf -e "${key} = ${value}"
    done < "$(g_locate_config_file postfix/main.keys)"
}
w_apply_postfix
g_log_success "Expéditeur local réécrit, tout part comme ${G_POSTFIX_MAIL_ADDRESS}"

g_log_info "Redémarrage de Postfix"
g_run_silent systemctl restart postfix
if ! systemctl is-active --quiet postfix; then
    g_log_error "Postfix n'est pas actif après la configuration."
fi
g_log_success "Postfix activé, écoute limitée à localhost"
