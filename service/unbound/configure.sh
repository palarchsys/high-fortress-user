#!/usr/bin/env bash
# =============================================================================
# File       : service/unbound/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root

hf_log_title "Configuration Unbound (DNS local)"
hf_log_info "Configuration d'Unbound"

if [[ ! -f /usr/share/dns/root.hints ]]; then
    hf_log_error "dns-root-data est incomplet : /usr/share/dns/root.hints absent"
fi

hf_ensure_directory /etc/unbound/unbound.conf.d 755
install -m 644 "$(hf_locate_config_file unbound/unbound.conf)" /etc/unbound/unbound.conf.d/high-fortress-user.conf

grep -v '^#' "$(hf_locate_config_file unbound/default-unbound)" > /etc/default/unbound
chmod 644 /etc/default/unbound
if [[ -f /etc/resolvconf/update.d/unbound ]]; then
    chmod a-x /etc/resolvconf/update.d/unbound
fi

check_out="$(unbound-checkconf 2>&1)" || hf_log_error "unbound-checkconf refuse la configuration : ${check_out}"

hf_ensure_directory /etc/systemd/resolved.conf.d 755
grep -v '^#' "$(hf_locate_config_file unbound/resolved.conf)" > /etc/systemd/resolved.conf.d/90-high-fortress-user.conf
chmod 644 /etc/systemd/resolved.conf.d/90-high-fortress-user.conf

hf_ensure_directory /etc/systemd/system/systemd-resolved.service.d 755
grep -v '^#' "$(hf_locate_config_file unbound/resolved.service.conf)" > /etc/systemd/system/systemd-resolved.service.d/90-high-fortress-user.conf
chmod 644 /etc/systemd/system/systemd-resolved.service.d/90-high-fortress-user.conf

hf_ensure_directory /etc/systemd/system/unbound.service.d 755
grep -v '^#' "$(hf_locate_config_file unbound/unbound.service.conf)" > /etc/systemd/system/unbound.service.d/90-high-fortress-user.conf
chmod 644 /etc/systemd/system/unbound.service.d/90-high-fortress-user.conf

install -m 644 "$(hf_locate_config_file unbound/root-hints.service)" /etc/systemd/system/hfu-unbound-root-hints.service
install -m 644 "$(hf_locate_config_file unbound/root-hints.path)" /etc/systemd/system/hfu-unbound-root-hints.path

hf_ensure_directory /etc/NetworkManager/conf.d 755
grep -v '^#' "$(hf_locate_config_file unbound/networkmanager.conf)" > /etc/NetworkManager/conf.d/90-high-fortress-user-dns.conf
chmod 644 /etc/NetworkManager/conf.d/90-high-fortress-user-dns.conf

install -d -m 755 /etc/NetworkManager/dispatcher.d
install -m 755 "${DIR_SCRIPT_PATH}/nm-dispatcher.sh" \
    /etc/NetworkManager/dispatcher.d/10-high-fortress-user-dns

if command -v nmcli >/dev/null 2>&1; then
    while IFS=: read -r uuid ctype; do
        [[ -n "${uuid}" ]] || continue
        case "${ctype}" in
            802-3-ethernet|802-11-wireless|gsm|cdma)
                hf_run_optional nmcli connection modify "${uuid}" \
                    ipv4.ignore-auto-dns yes \
                    ipv6.ignore-auto-dns yes \
                    ipv4.dns 127.0.0.1 \
                    ipv6.dns ::1
                ;;
        esac
    done < <(nmcli -t -f UUID,TYPE connection show 2>/dev/null || true)
fi

hf_run_optional systemctl disable --now unbound-resolvconf.service
hf_run_silent systemctl daemon-reload
hf_run_silent systemctl enable unbound.service
hf_run_silent systemctl restart unbound.service
hf_run_silent systemctl enable --now hfu-unbound-root-hints.path
hf_run_silent systemctl restart systemd-resolved.service
hf_run_optional systemctl reload NetworkManager

if command -v nmcli >/dev/null 2>&1; then
    while IFS=: read -r dev dtype; do
        [[ -n "${dev}" ]] || continue
        case "${dtype}" in
            ethernet|wifi|gsm)
                hf_run_optional resolvectl dns "${dev}" 127.0.0.1 ::1
                ;;
        esac
    done < <(nmcli -t -f DEVICE,TYPE device status 2>/dev/null || true)
fi
hf_run_optional resolvectl flush-caches

ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if unbound-control status >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "${ready}" -ne 1 ]]; then
    hf_log_error "Unbound n'est pas prêt après le démarrage du service"
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
    hf_log_error "La résolution locale via Unbound a échoué : ${query_out}"
fi

hf_log_success "Unbound configuré (résolution sur le poste, racines à jour)"
