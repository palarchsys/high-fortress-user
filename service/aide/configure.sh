#!/usr/bin/env bash
# =============================================================================
# File       : service/aide/configure.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root
detect_current_user

title "Configuration AIDE"
info "Configuration d'AIDE"
ensure_dir /etc/aide 755
ensure_dir /var/lib/aide 700
sed "s|__HF_BASE__|${CONFIG_BASE_DIR}|g" "${DIR_SCRIPT_PATH}/aide.conf" > /etc/aide/aide.conf
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
install -d -m 755 "${CONFIG_BASE_DIR}/bin"
install -m 755 "${DIR_SCRIPT_PATH}/refresh-db.sh" "${CONFIG_BASE_DIR}/bin/aide-refresh-db.sh"
success "aide.conf posé"
info "Base AIDE après la purge des paquets et rkhunter."
