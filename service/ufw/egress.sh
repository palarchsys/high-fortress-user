#!/usr/bin/env bash
# =============================================================================
# File       : service/ufw/egress.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================
# -----------------------------------------------------------------------------
# Note       : The log table is installed on every configure.
# Note       : The outbound policy stays allow.
# -----------------------------------------------------------------------------

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root
# shellcheck disable=SC1091
source "$(g_locate_config_file ufw/egress.conf)"

install -d -m 750 "${G_CONFIG_BASE_DIRECTORY}/cron"
umask 077
cat > "${G_CONFIG_BASE_DIRECTORY}/cron/egress.conf" << EOF
W_NET_ISOLATE_SEC=${W_NET_ISOLATE_SEC}
EOF
umask 022
chmod 600 "${G_CONFIG_BASE_DIRECTORY}/cron/egress.conf"

g_log_title "Journal des flux sortants"
install -d -m 755 "${G_CONFIG_BASE_DIRECTORY}/cron/bin"
cat > "${G_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh" << 'EOF'
#!/bin/bash
set -euo pipefail
command -v nft >/dev/null 2>&1 || exit 0
nft delete table inet w_egress >/dev/null 2>&1 || true
nft add table inet w_egress
nft add chain inet w_egress output '{ type filter hook output priority 0 ; policy accept ; }'
nft add rule inet w_egress output ct state established,related accept
nft add rule inet w_egress output ip daddr 127.0.0.0/8 accept
nft add rule inet w_egress output ip6 daddr ::1 accept
nft add rule inet w_egress output meta l4proto '{ tcp, udp }' th dport '{ 53, 80, 443 }' accept
# Workstation baseline: time sync, link-local discovery, DHCP. Other TCP/UDP stays logged.
nft add rule inet w_egress output meta l4proto udp th dport 123 accept
nft add rule inet w_egress output meta l4proto tcp th dport 4460 accept
nft add rule inet w_egress output ip daddr 224.0.0.251 meta l4proto udp th dport 5353 accept
nft add rule inet w_egress output ip6 daddr ff02::fb meta l4proto udp th dport 5353 accept
nft add rule inet w_egress output meta l4proto udp th sport 68 th dport 67 accept
nft add rule inet w_egress output meta l4proto udp th sport 546 th dport 547 accept
nft add rule inet w_egress output meta l4proto udp th dport 161 meta pkttype '{ broadcast, multicast }' accept
nft add rule inet w_egress output meta l4proto '{ tcp, udp }' limit rate 30/minute log prefix 'w-egress '
EOF
chmod 755 "${G_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh"
cat > /etc/systemd/system/w-egress-table.service << EOF
[Unit]
Description=Pose le journal des flux sortants
After=ufw.service
Before=w-boot-chain.service

[Service]
Type=oneshot
ExecStart=${G_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/w-egress-table.service
g_run_silent systemctl daemon-reload
g_run_silent systemctl enable w-egress-table.service

if ! command -v nft >/dev/null 2>&1; then
    g_log_warn "nft absent : journal des flux sortants non posé"
    exit 0
fi
g_log_info "Pose du journal des flux sortants"
bash "${G_CONFIG_BASE_DIRECTORY}/cron/bin/egress-table.sh"
g_log_success "Journal des flux sortants actif"
