#!/usr/bin/env bash
# =============================================================================
# File       : service/ufw/configure.sh
# Updated at : 2026-10-14
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"
require_root
detect_ssh_port

title "Configuration UFW (desktop-safe)"
backup_file_once /etc/default/ufw
backup_file_once /etc/ufw/before.rules

info "Politique : deny incoming, ALLOW outgoing, routed ACCEPT"
run_silent ufw default deny incoming
run_silent ufw default allow outgoing

if grep -q '^DEFAULT_FORWARD_POLICY=' /etc/default/ufw; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
else
    echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' >> /etc/default/ufw
fi
run_silent ufw default allow routed

if grep -q '^IPT_MODULES=' /etc/default/ufw; then
    if ! awk -F= '/^IPT_MODULES=/{print}' /etc/default/ufw | grep -q bridge; then
        ipt_val="$(awk -F= '/^IPT_MODULES=/{print substr($0, index($0,"=")+1)}' /etc/default/ufw)"
        ipt_val="${ipt_val#\"}"
        ipt_val="${ipt_val%\"}"
        ipt_val="${ipt_val#\'}"
        ipt_val="${ipt_val%\'}"
        sed -i "s|^IPT_MODULES=.*|IPT_MODULES=\"${ipt_val} bridge\"|" /etc/default/ufw
    fi
else
    echo 'IPT_MODULES="bridge"' >> /etc/default/ufw
fi
if [[ -f /etc/ufw/sysctl.conf ]] && ! grep -q 'bridge-nf-call-iptables' /etc/ufw/sysctl.conf; then
    cat >> /etc/ufw/sysctl.conf << 'EOF'

net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
EOF
fi

if grep -q '^IPV6=' /etc/default/ufw; then
    sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
else
    echo "IPV6=yes" >> /etc/default/ufw
fi

run_silent ufw logging medium

info "SSH limit sur le port détecté ${SSH_PORT}/tcp"

hfu_ufw_delete_marked() {
    local nums n
    mapfile -t nums < <(LANG=C LC_ALL=C ufw status numbered \
        | sed -n 's/^\[\s*\([0-9][0-9]*\)\].*\(SSH (limit)\|SSH LAN\).*/\1/p' \
        | sort -nr)
    for n in "${nums[@]+"${nums[@]}"}"; do
        [[ -n "${n}" ]] || continue
        run_silent ufw --force delete "${n}"
    done
}

mapfile -t ssh_prefixes < <(ip -o addr show up scope global 2>/dev/null | awk '{print $4}')
if ip -o -6 addr show up scope link 2>/dev/null | grep -q 'fe80:'; then
    ssh_prefixes+=("fe80::/10")
fi
kept_prefixes=()
for prefix in "${ssh_prefixes[@]+"${ssh_prefixes[@]}"}"; do
    mask="${prefix##*/}"
    [[ "${mask}" == "0" || "${mask}" == "${prefix}" ]] && continue
    kept_prefixes+=("${prefix}")
done
deduped_prefixes=()
for prefix in "${kept_prefixes[@]+"${kept_prefixes[@]}"}"; do
    already=0
    for seen_prefix in "${deduped_prefixes[@]+"${deduped_prefixes[@]}"}"; do
        if [[ "${seen_prefix}" == "${prefix}" ]]; then
            already=1
            break
        fi
    done
    if [[ "${already}" -eq 0 ]]; then
        deduped_prefixes+=("${prefix}")
    fi
done
kept_prefixes=()
for prefix in "${deduped_prefixes[@]+"${deduped_prefixes[@]}"}"; do
    kept_prefixes+=("${prefix}")
done

if [[ ${#kept_prefixes[@]} -eq 0 ]]; then
    if ! LANG=C LC_ALL=C ufw status | grep -q 'SSH (limit)'; then
        run_silent ufw limit "${SSH_PORT}/tcp" comment 'SSH (limit)'
    fi
    warn "Aucun préfixe connecté : SSH reste ouvert sur toutes les sources"
else
    hfu_ufw_delete_marked
    for prefix in "${kept_prefixes[@]}"; do
        run_silent ufw limit from "${prefix}" to any port "${SSH_PORT}" proto tcp comment 'SSH LAN'
    done
    success "SSH limité aux préfixes connectés (${kept_prefixes[*]})"
fi

run_silent ufw allow in on lo
run_silent ufw allow out on lo

title "Activation UFW"
info "Activation d'UFW"
run_silent ufw --force enable
if ! LANG=C LC_ALL=C ufw status | grep -qw "Status: active"; then
    error "UFW n'est pas actif après enable : $(LANG=C LC_ALL=C ufw status)"
fi
success "UFW activé (outgoing ALLOW — Steam/Discord/apt/Brave OK)"
