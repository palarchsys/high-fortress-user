#!/usr/bin/env bash
# =============================================================================
# File       : service/desktop/configure.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root
detect_current_user

title "Politique Brave"

info "Écriture de la politique Brave"
install -d -m 755 /etc/brave/policies/managed
mapfile -t http_hosts < <(printf '%s\n' localhost 127.0.0.1 '[::1]' '[*.]local')
while read -r gateway; do
    [[ -n "${gateway}" ]] || continue
    http_hosts+=("${gateway}")
done < <(ip -4 route show default 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "via") print $(i + 1)}')
python3 - "${http_hosts[@]}" << 'PY'
import json
import sys
hosts = []
for host in sys.argv[1:]:
    if host and host not in hosts:
        hosts.append(host)
policy = {
    "DnsOverHttpsMode": "off",
    "BuiltInDnsClientEnabled": False,
    "HttpsOnlyMode": "force_balanced_enabled",
    "HttpAllowlist": hosts,
    "DefaultWebUsbGuardSetting": 3,
    "DefaultWebHidGuardSetting": 3,
    "DefaultSerialGuardSetting": 3,
    "BrowserGuestModeEnabled": False,
}
with open("/etc/brave/policies/managed/high-fortress-user.json", "w", encoding="utf-8") as handle:
    json.dump(policy, handle, indent=2)
    handle.write("\n")
PY
chmod 644 /etc/brave/policies/managed/high-fortress-user.json
success "Politique Brave posée (DNS du poste, mode invité coupé)"

title "Politique Thunderbird"

info "Écriture de la politique Thunderbird"
install -d -m 755 /etc/thunderbird/policies
python3 - << 'PY'
import json
policy = {
    "policies": {
        "Preferences": {
            "mailnews.message_display.disable_remote_image": {
                "Value": True,
                "Status": "user",
            }
        }
    }
}
with open("/etc/thunderbird/policies/policies.json", "w", encoding="utf-8") as handle:
    json.dump(policy, handle, indent=2)
    handle.write("\n")
PY
chmod 644 /etc/thunderbird/policies/policies.json
success "Images distantes de Thunderbird affichées après un clic"

title "KeePassXC"

info "Verrou KeePassXC du compte ${CURRENT_USER}"
kpxc_dir="${CURRENT_HOME}/.config/keepassxc"
install -d -m 700 -o "${CURRENT_USER}" -g "${CURRENT_USER}" "${kpxc_dir}"
kpxc_ini="${kpxc_dir}/keepassxc.ini"
if [[ ! -f "${kpxc_ini}" ]]; then
    install -m 600 -o "${CURRENT_USER}" -g "${CURRENT_USER}" /dev/null "${kpxc_ini}"
fi
python3 - "${kpxc_ini}" << 'PY'
import configparser
import sys
path = sys.argv[1]
cfg = configparser.ConfigParser(interpolation=None)
cfg.optionxform = str
cfg.read(path)
if not cfg.has_section("Security"):
    cfg.add_section("Security")
cfg.set("Security", "LockDatabaseScreenLock", "true")
cfg.set("Security", "LockDatabaseIdle", "true")
cfg.set("Security", "LockDatabaseIdleSeconds", "900")
with open(path, "w", encoding="utf-8") as handle:
    cfg.write(handle)
PY
chown "${CURRENT_USER}:${CURRENT_USER}" "${kpxc_ini}"
chmod 600 "${kpxc_ini}"
success "KeePassXC se ferme avec la session"

title "Verrou de session"

info "Verrou GNOME à 20 minutes, sans changer la mise en veille"
if command -v gsettings >/dev/null 2>&1 && command -v dbus-run-session >/dev/null 2>&1; then
    hfu_gset() {
        local schema="$1" key="$2" value="$3"
        if sudo -u "${CURRENT_USER}" -H dbus-run-session -- gsettings set "${schema}" "${key}" "${value}" >/dev/null 2>&1; then
            return 0
        fi
        warn "Réglage GNOME ignoré : ${schema} ${key}"
        return 0
    }
    hfu_gset org.gnome.desktop.session idle-delay 1200
    hfu_gset org.gnome.desktop.screensaver lock-enabled true
    hfu_gset org.gnome.desktop.screensaver lock-delay 0
    hfu_gset org.gnome.desktop.screensaver ubuntu-lock-on-suspend true
    success "Session verrouillée après 20 minutes d'inactivité"
else
    warn "gsettings absent : verrou de session non posé"
fi
