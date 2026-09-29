#!/bin/bash
# =============================================================================
# Fichier    : service/unbound/nm-dispatcher.sh
# Créé le    : 2026-09-29
# Créateur   : palarchsys
#
# Rôle
#   Sur une liaison ethernet ou Wi-Fi, pointe systemd-resolved vers
#   Unbound. Un VPN conserve le DNS fourni par le tunnel.
# =============================================================================

interface="${1:-}"
action="${2:-}"
case "${action}" in
    up|dhcp4-change|dhcp6-change|reapply) ;;
    *) exit 0 ;;
esac
[[ -n "${interface}" ]] || exit 0
case "${interface}" in
    lo|virbr*|vnet*|docker*|br-*|veth*|tailscale*|zt*)
        exit 0
        ;;
esac
if command -v nmcli >/dev/null 2>&1; then
    conn="$(nmcli -g GENERAL.CONNECTION device show "${interface}" 2>/dev/null || true)"
    if [[ -n "${conn}" ]]; then
        ctype="$(nmcli -g connection.type connection show "${conn}" 2>/dev/null || true)"
        case "${ctype}" in
            vpn|wireguard|tun|bridge|loopback|ip-tunnel)
                exit 0
                ;;
        esac
    fi
fi
if command -v resolvectl >/dev/null 2>&1; then
    resolvectl dns "${interface}" 127.0.0.1 ::1 >/dev/null 2>&1 \
        || resolvectl dns "${interface}" 127.0.0.1 >/dev/null 2>&1 \
        || true
fi
exit 0
