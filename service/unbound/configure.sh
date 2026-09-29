#!/usr/bin/env bash
# =============================================================================
# Fichier    : service/unbound/configure.sh
# Créé le    : 2026-09-29
# Créateur   : palarchsys
#
# Rôle
#   service/unbound/configure.sh
# =============================================================================

# Unbound écoute 127.0.0.1 et ::1. systemd-resolved reste le résolveur
# vu par les applications. Les liaisons ethernet et Wi-Fi ignorent le
# DNS du DHCP (FAI). Un VPN NetworkManager garde le DNS du tunnel.
# La liste des serveurs racine vient de dns-root-data et est rechargée
# quand le paquet est mis à jour.
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

title "Configuration Unbound (DNS local)"

if [[ ! -f /usr/share/dns/root.hints ]]; then
    error "dns-root-data est incomplet : /usr/share/dns/root.hints absent"
fi

ensure_dir /etc/unbound/unbound.conf.d 755
install -m 644 "${DIR_SCRIPT_PATH}/unbound.conf" /etc/unbound/unbound.conf.d/high-fortress-user.conf

# Ne pas recopier le DNS du FAI comme forwarder Unbound.
tee /etc/default/unbound > /dev/null << 'EOF'
RESOLVCONF=false
ROOT_TRUST_ANCHOR_UPDATE=true
USE_RESOLVCONF_FORWARDS=false
EOF
chmod 644 /etc/default/unbound
if [[ -f /etc/resolvconf/update.d/unbound ]]; then
    chmod a-x /etc/resolvconf/update.d/unbound
fi

check_out="$(unbound-checkconf 2>&1)" || error "unbound-checkconf refuse la configuration : ${check_out}"

ensure_dir /etc/systemd/resolved.conf.d 755
tee /etc/systemd/resolved.conf.d/90-high-fortress-user.conf > /dev/null << 'EOF'
[Resolve]
DNS=127.0.0.1
DNS=::1
FallbackDNS=
DNSSEC=no
DNSOverTLS=no
EOF
chmod 644 /etc/systemd/resolved.conf.d/90-high-fortress-user.conf

ensure_dir /etc/systemd/system/systemd-resolved.service.d 755
tee /etc/systemd/system/systemd-resolved.service.d/90-high-fortress-user.conf > /dev/null << 'EOF'
[Unit]
After=unbound.service
Wants=unbound.service
EOF
chmod 644 /etc/systemd/system/systemd-resolved.service.d/90-high-fortress-user.conf

ensure_dir /etc/systemd/system/unbound.service.d 755
tee /etc/systemd/system/unbound.service.d/90-high-fortress-user.conf > /dev/null << 'EOF'
[Unit]
Before=systemd-resolved.service nss-lookup.target
Wants=nss-lookup.target
EOF
chmod 644 /etc/systemd/system/unbound.service.d/90-high-fortress-user.conf

install -m 644 "${DIR_SCRIPT_PATH}/root-hints.service" /etc/systemd/system/hfu-unbound-root-hints.service
install -m 644 "${DIR_SCRIPT_PATH}/root-hints.path" /etc/systemd/system/hfu-unbound-root-hints.path

ensure_dir /etc/NetworkManager/conf.d 755
tee /etc/NetworkManager/conf.d/90-high-fortress-user-dns.conf > /dev/null << 'EOF'
[main]
dns=systemd-resolved

[connection]
ipv4.ignore-auto-dns=true
ipv6.ignore-auto-dns=true
EOF
chmod 644 /etc/NetworkManager/conf.d/90-high-fortress-user-dns.conf

install -d -m 755 /etc/NetworkManager/dispatcher.d
install -m 755 "${DIR_SCRIPT_PATH}/nm-dispatcher.sh" \
    /etc/NetworkManager/dispatcher.d/10-high-fortress-user-dns

if command -v nmcli >/dev/null 2>&1; then
    while IFS=: read -r uuid ctype; do
        [[ -n "${uuid}" ]] || continue
        case "${ctype}" in
            802-3-ethernet|802-11-wireless|gsm|cdma)
                try_silent nmcli connection modify "${uuid}" \
                    ipv4.ignore-auto-dns yes \
                    ipv6.ignore-auto-dns yes \
                    ipv4.dns 127.0.0.1 \
                    ipv6.dns ::1
                ;;
        esac
    done < <(nmcli -t -f UUID,TYPE connection show 2>/dev/null || true)
fi

try_silent systemctl disable --now unbound-resolvconf.service
run_silent systemctl daemon-reload
run_silent systemctl enable unbound.service
run_silent systemctl restart unbound.service
run_silent systemctl enable --now hfu-unbound-root-hints.path
run_silent systemctl restart systemd-resolved.service
try_silent systemctl reload NetworkManager

if command -v nmcli >/dev/null 2>&1; then
    while IFS=: read -r dev dtype; do
        [[ -n "${dev}" ]] || continue
        case "${dtype}" in
            ethernet|wifi|gsm)
                try_silent resolvectl dns "${dev}" 127.0.0.1 ::1
                ;;
        esac
    done < <(nmcli -t -f DEVICE,TYPE device status 2>/dev/null || true)
fi
try_silent resolvectl flush-caches

ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if unbound-control status >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "${ready}" -ne 1 ]]; then
    error "Unbound n'est pas prêt après le démarrage du service"
fi

resolved=0
query_out=""
for _ in 1 2 3 4 5; do
    query_out="$(resolvectl query ubuntu.com 2>&1)" && {
        resolved=1
        break
    }
    sleep 2
done
if [[ "${resolved}" -ne 1 ]]; then
    error "La résolution locale via Unbound a échoué : ${query_out}"
fi

success "Unbound résout les noms sur le poste (serveurs racine tenus à jour)"
