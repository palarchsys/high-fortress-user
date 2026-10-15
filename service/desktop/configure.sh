#!/usr/bin/env bash
# =============================================================================
# File       : service/desktop/configure.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
hf_get_current_user

hf_log_title "Politique Brave"

hf_log_info "Écriture de la politique Brave"
install -d -m 755 /etc/brave/policies/managed
mapfile -t http_hosts < <(printf '%s\n' localhost 127.0.0.1 '[::1]' '[*.]local')
while read -r gateway; do
    [[ -n "${gateway}" ]] || continue
    http_hosts+=("${gateway}")
done < <(ip -4 route show default 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "via") print $(i + 1)}')
python3 - "$(hf_locate_config_file desktop/brave-policy.json)" "${http_hosts[@]}" << 'PY'
import json
import sys
raw = open(sys.argv[1], encoding="utf-8").read().splitlines()
body = "\n".join(line for line in raw if not line.startswith("#"))
policy = json.loads(body)
hosts = []
for host in sys.argv[2:]:
    if host and host not in hosts:
        hosts.append(host)
policy["HttpAllowlist"] = hosts
with open("/etc/brave/policies/managed/high-fortress-user.json", "w", encoding="utf-8") as handle:
    json.dump(policy, handle, indent=2)
    handle.write("\n")
PY
chmod 644 /etc/brave/policies/managed/high-fortress-user.json
hf_log_success "Politique Brave posée (DNS du poste, mode invité coupé)"

hf_log_title "Politique Thunderbird"

hf_log_info "Écriture de la politique Thunderbird"
install -d -m 755 /etc/thunderbird/policies
python3 - "$(hf_locate_config_file desktop/thunderbird-policy.json)" << 'PY'
import json
import sys
raw = open(sys.argv[1], encoding="utf-8").read().splitlines()
body = "\n".join(line for line in raw if not line.startswith("#"))
policy = json.loads(body)
with open("/etc/thunderbird/policies/policies.json", "w", encoding="utf-8") as handle:
    json.dump(policy, handle, indent=2)
    handle.write("\n")
PY
chmod 644 /etc/thunderbird/policies/policies.json
hf_log_success "Images distantes de Thunderbird affichées après un clic"

hf_log_title "KeePassXC"

hf_log_info "Verrou KeePassXC du compte ${CURRENT_USER}"
kpxc_dir="${CURRENT_HOME}/.config/keepassxc"
install -d -m 700 -o "${CURRENT_USER}" -g "${CURRENT_USER}" "${kpxc_dir}"
kpxc_ini="${kpxc_dir}/keepassxc.ini"
if [[ ! -f "${kpxc_ini}" ]]; then
    install -m 600 -o "${CURRENT_USER}" -g "${CURRENT_USER}" /dev/null "${kpxc_ini}"
fi
python3 - "${kpxc_ini}" "$(hf_locate_config_file desktop/keepassxc.conf)" << 'PY'
import configparser
import sys
path = sys.argv[1]
conf = sys.argv[2]
cfg = configparser.ConfigParser(interpolation=None)
cfg.optionxform = str
cfg.read(path)
if not cfg.has_section("Security"):
    cfg.add_section("Security")
for line in open(conf, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    cfg.set("Security", key, value)
with open(path, "w", encoding="utf-8") as handle:
    cfg.write(handle)
PY
chown "${CURRENT_USER}:${CURRENT_USER}" "${kpxc_ini}"
chmod 600 "${kpxc_ini}"
hf_log_success "KeePassXC se ferme avec la session"

hf_log_title "Verrou de session"

hf_log_info "Verrou GNOME à 20 minutes, sans changer la mise en veille"
if command -v gsettings >/dev/null 2>&1 && command -v dbus-run-session >/dev/null 2>&1; then
    hfu_set_gnome_key() {
        local schema="$1" key="$2" value="$3"
        if sudo -u "${CURRENT_USER}" -H dbus-run-session -- gsettings set "${schema}" "${key}" "${value}" >/dev/null 2>&1; then
            return 0
        fi
        hf_log_warn "Réglage GNOME ignoré : ${schema} ${key}"
        return 0
    }
    while read -r schema key value; do
        [[ -n "${schema}" && "${schema}" != \#* ]] || continue
        hfu_set_gnome_key "${schema}" "${key}" "${value}"
    done < "$(hf_locate_config_file desktop/gnome.list)"
    hf_log_success "Session verrouillée après 20 minutes d'inactivité"
else
    hf_log_warn "gsettings absent : verrou de session non posé"
fi
