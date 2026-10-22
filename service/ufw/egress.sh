#!/usr/bin/env bash
# =============================================================================
# File       : service/ufw/egress.sh
# Updated at : 2026-10-21
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Note       : The log table is installed on every configure.
# Note       : The outbound policy stays allow.
# -----------------------------------------------------------------------------

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"
hf_require_root
# shellcheck disable=SC1091
source "$(hf_locate_config_file ufw/egress.conf)"

install -d -m 750 "${HF_CONFIG_BASE_DIRECTORY}/cron"
umask 077
cat > "${HF_CONFIG_BASE_DIRECTORY}/cron/egress.conf" << EOF
HFU_NET_ISOLATE_SEC=${HFU_NET_ISOLATE_SEC}
EOF
umask 022
chmod 600 "${HF_CONFIG_BASE_DIRECTORY}/cron/egress.conf"

hf_log_title "Journal des flux sortants"
install -d -m 755 "${HF_CONFIG_BASE_DIRECTORY}/cron/bin"
cat > "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh" << 'EOF'
#!/bin/bash
set -euo pipefail
command -v nft >/dev/null 2>&1 || exit 0
nft delete table inet hfu_egress >/dev/null 2>&1 || true
nft add table inet hfu_egress
nft add chain inet hfu_egress output '{ type filter hook output priority 0 ; policy accept ; }'
nft add rule inet hfu_egress output ct state established,related accept
nft add rule inet hfu_egress output ip daddr 127.0.0.0/8 accept
nft add rule inet hfu_egress output ip6 daddr ::1 accept
nft add rule inet hfu_egress output meta l4proto '{ tcp, udp }' th dport '{ 53, 80, 443 }' accept
nft add rule inet hfu_egress output meta l4proto '{ tcp, udp }' limit rate 30/minute log prefix 'hfu-egress '
EOF
chmod 755 "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh"
cat > /etc/systemd/system/hfu-egress-table.service << EOF
[Unit]
Description=Pose le journal des flux sortants
After=ufw.service
Before=hfu-boot-chain.service

[Service]
Type=oneshot
ExecStart=${HF_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/hfu-egress-table.service
hf_run_silent systemctl daemon-reload
hf_run_silent systemctl enable hfu-egress-table.service

if ! command -v nft >/dev/null 2>&1; then
    hf_log_warn "nft absent : journal des flux sortants non posé"
    exit 0
fi
hf_log_info "Pose du journal des flux sortants"
bash "${HF_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh"
hf_log_success "Journal des flux sortants actif"
