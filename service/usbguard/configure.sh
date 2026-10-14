#!/usr/bin/env bash
# =============================================================================
# File       : service/usbguard/configure.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root
detect_current_user

title "Politique USBGuard"

info "Écriture des règles USBGuard"
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
printf '%s\n' 'allow with-interface equals { 03:*:* }' >> "${rules}"
printf '%s\n' 'allow with-interface equals { 09:*:* }' >> "${rules}"
chmod 600 "${rules}"
if ! grep -q 'allow with-interface equals { 03:\*:\* }' "${rules}"; then
    warn "USBGuard laissé arrêté : la règle clavier manque"
    try_silent systemctl disable --now usbguard
    exit 0
fi

daemon_conf=/etc/usbguard/usbguard-daemon.conf
if [[ ! -f "${daemon_conf}" ]]; then
    install -m 600 /dev/null "${daemon_conf}"
fi
hfu_usb_set() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "${daemon_conf}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${daemon_conf}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${daemon_conf}"
    fi
}
hfu_usb_set RuleFile /etc/usbguard/rules.conf
hfu_usb_set ImplicitPolicyTarget block
hfu_usb_set PresentDevicePolicy apply-policy
hfu_usb_set PresentControllerPolicy keep
hfu_usb_set InsertedDevicePolicy apply-policy
hfu_usb_set RestoreControllerDeviceState false
hfu_usb_set IPCAllowedUsers "root ${CURRENT_USER}"
hfu_usb_set IPCAccessControlFiles /etc/usbguard/IPCAccessControl.d/
chmod 600 "${daemon_conf}"

ipc="/etc/usbguard/IPCAccessControl.d/${CURRENT_USER}"
cat > "${ipc}" << 'EOF'
Devices=modify,list,listen
Policy=list
Exceptions=listen
EOF
chmod 600 "${ipc}"

info "Activation de USBGuard"
if systemctl enable --now usbguard >/dev/null 2>&1; then
    success "USBGuard actif (appareils présents et HID autorisés)"
else
    warn "USBGuard n'a pas démarré — service laissé arrêté"
    try_silent systemctl disable --now usbguard
fi
