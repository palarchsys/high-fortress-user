#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/configure.sh
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
hf_get_current_user

hf_log_title "Configuration AIDE"
hf_log_info "Configuration d'AIDE"
hf_ensure_directory /etc/aide 755
hf_ensure_directory /var/lib/aide 700
sed "s|__HF_BASE__|${HF_CONFIG_BASE_DIRECTORY}|g" "$(hf_locate_config_file aide/aide.conf)" > /etc/aide/aide.conf
python3 - /etc/aide/aide.conf "${CURRENT_HOME}" << 'PY'
import sys
from pathlib import Path
path, home = Path(sys.argv[1]), sys.argv[2].rstrip("/")
text = path.read_text()
begin = "# BEGIN High-Fortress User account"
end = "# END High-Fortress User account"
lines = text.splitlines()
out = []
skip = False
for line in lines:
    if line.strip() == begin:
        skip = True
        continue
    if line.strip() == end:
        skip = False
        continue
    if not skip:
        out.append(line)
names = [
    f"{home}/.ssh/authorized_keys",
    f"{home}/.bashrc",
    f"{home}/.profile",
    f"{home}/.bash_profile",
    f"{home}/.config/autostart",
    f"{home}/.config/systemd/user",
]
block = [begin]
block.extend(f"{name} All" for name in names)
block.append(f"!{home}/.ssh/known_hosts")
block.append(f"!{home}/.ssh/known_hosts.old")
block.append(end)
out.extend(block)
path.write_text("\n".join(out) + "\n")
PY
install -d -m 755 "${HF_CONFIG_BASE_DIRECTORY}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/refresh-db.sh" "${HF_CONFIG_BASE_DIRECTORY}/bin/aide-refresh-db.sh"
hf_log_success "aide.conf posé"
hf_log_info "Base AIDE après la purge des paquets et rkhunter."
