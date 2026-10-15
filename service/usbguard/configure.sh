#!/usr/bin/env bash
# =============================================================================
# File       : service/usbguard/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
hf_get_current_user

hf_log_title "Politique USBGuard"

hf_log_info "Écriture des règles USBGuard"
install -d -m 750 /etc/usbguard /etc/usbguard/IPCAccessControl.d
rules=/etc/usbguard/rules.conf
: > "${rules}"
if command -v usbguard >/dev/null 2>&1; then
    usbguard generate-policy > "${rules}.gen" 2>/dev/null || true
    if [[ -s "${rules}.gen" ]]; then
        cat "${rules}.gen" > "${rules}"
    fi
    rm -f "${rules}.gen"
fi
grep -v '^#' "$(hf_locate_config_file usbguard/hid.rules)" >> "${rules}"
chmod 600 "${rules}"
if ! grep -qF 'allow with-interface equals { 03:*:* }' "${rules}"; then
    hf_log_warn "USBGuard laissé arrêté : la règle clavier manque"
    hf_run_optional systemctl disable --now usbguard
    exit 0
fi

daemon_conf=/etc/usbguard/usbguard-daemon.conf
if [[ ! -f "${daemon_conf}" ]]; then
    install -m 600 /dev/null "${daemon_conf}"
fi

hfu_set_usb_rule() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "${daemon_conf}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${daemon_conf}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${daemon_conf}"
    fi
}

hfu_load_usb_rule() {
    local line key value
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        hfu_set_usb_rule "${key}" "${value}"
    done < "$(hf_locate_config_file usbguard/daemon.conf)"
}
hfu_load_usb_rule
hfu_set_usb_rule IPCAllowedUsers "root ${CURRENT_USER}"
chmod 600 "${daemon_conf}"

ipc="/etc/usbguard/IPCAccessControl.d/${CURRENT_USER}"
grep -v '^#' "$(hf_locate_config_file usbguard/ipc.acl)" > "${ipc}"
chmod 600 "${ipc}"

hf_log_info "Activation de USBGuard"
if systemctl enable --now usbguard >/dev/null 2>&1; then
    hf_log_success "USBGuard actif (appareils présents et HID autorisés)"
else
    hf_log_warn "USBGuard n'a pas démarré — service laissé arrêté"
    hf_run_optional systemctl disable --now usbguard
fi
