#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/postfix/configure.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   service/postfix/configure.sh
# =============================================================================

# Relais SMTP authentifié en TLS, écoute limitée à la machine.
# Le login SMTP et l'adresse From peuvent différer. Les alertes
# partent vers From. L'hôte saisi hôte:port devient [hôte]:port.
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root

if [[ "${HF_MAIL_ALERTS:-0}" != "1" ]]; then
    info "Alertes e-mail coupées : Postfix n'est pas configuré."
    exit 0
fi

title "Identifiants SMTP"
relay_host="${POSTFIX_MAIL_SMTP%:*}"
relay_port="${POSTFIX_MAIL_SMTP##*:}"
relayhost="[${relay_host}]:${relay_port}"
install -d -m 755 /etc/postfix
umask 077
printf '%s %s:%s\n' "${relayhost}" "${POSTFIX_SMTP_LOGIN}" "${POSTFIX_MAIL_PASS}" \
    > /etc/postfix/sasl_passwd
umask 022
run_silent postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
success "Carte SASL enregistrée (lecture root seulement)"

title "Nom de courrier"
printf '%s\n' "$(hostname -f)" > /etc/mailname
chmod 644 /etc/mailname
success "mailname = $(hostname -f)"

title "Relais et réécriture de l'expéditeur"
postconf -e "myhostname = $(hostname -f)"
postconf -e "myorigin = /etc/mailname"
postconf -e "relayhost = ${relayhost}"
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "smtp_tls_security_level = encrypt"
postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
postconf -e "inet_interfaces = loopback-only"
postconf -e "inet_protocols = all"
postconf -e "default_transport = smtp"
postconf -e "smtpd_banner = ${PROJECT_NAME} ESMTP"
postconf -e "disable_vrfy_command = yes"
# Table regexp : Postfix lit le fichier texte, pas une base postmap.
printf '/.*/ %s\n' "${POSTFIX_MAIL_ADDRESS}" > /etc/postfix/sender_canonical
chmod 644 /etc/postfix/sender_canonical
postconf -e "sender_canonical_maps = regexp:/etc/postfix/sender_canonical"
success "Tout expéditeur local part comme ${POSTFIX_MAIL_ADDRESS}"

run_silent systemctl restart postfix
if ! systemctl is-active --quiet postfix; then
    error "Postfix n'est pas actif après la configuration."
fi
success "Postfix actif, écoute limitée à localhost"
