#!/usr/bin/env bash
# =============================================================================
# File       : service/ufw/configure.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"
g_require_root
g_get_ssh_port

g_log_title "Configuration UFW (desktop-safe)"
g_copy_backup /etc/default/ufw
g_copy_backup /etc/ufw/before.rules

# shellcheck disable=SC1091
source "$(g_locate_config_file ufw/policy.conf)"

g_log_info "Politique : ${W_UFW_DEFAULT_INCOMING} incoming, ${W_UFW_DEFAULT_OUTGOING} outgoing, routed ${W_UFW_DEFAULT_ROUTED}"
g_run_silent ufw default "${W_UFW_DEFAULT_INCOMING}" incoming
g_run_silent ufw default "${W_UFW_DEFAULT_OUTGOING}" outgoing

if grep -q '^DEFAULT_FORWARD_POLICY=' /etc/default/ufw; then
    sed -i "s/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=\"${W_UFW_FORWARD_POLICY}\"/" /etc/default/ufw
else
    echo "DEFAULT_FORWARD_POLICY=\"${W_UFW_FORWARD_POLICY}\"" >> /etc/default/ufw
fi
g_run_silent ufw default "${W_UFW_DEFAULT_ROUTED}" routed

if grep -q '^IPT_MODULES=' /etc/default/ufw; then
    if ! awk -F= '/^IPT_MODULES=/{print}' /etc/default/ufw | grep -q "${W_UFW_IPT_EXTRA}"; then
        ipt_val="$(awk -F= '/^IPT_MODULES=/{print substr($0, index($0,"=")+1)}' /etc/default/ufw)"
        ipt_val="${ipt_val#\"}"
        ipt_val="${ipt_val%\"}"
        ipt_val="${ipt_val#\'}"
        ipt_val="${ipt_val%\'}"
        sed -i "s|^IPT_MODULES=.*|IPT_MODULES=\"${ipt_val} ${W_UFW_IPT_EXTRA}\"|" /etc/default/ufw
    fi
else
    echo "IPT_MODULES=\"${W_UFW_IPT_EXTRA}\"" >> /etc/default/ufw
fi
if [[ -f /etc/ufw/sysctl.conf ]] && ! grep -q 'bridge-nf-call-iptables' /etc/ufw/sysctl.conf; then
    printf '\n' >> /etc/ufw/sysctl.conf
    grep -v '^#' "$(g_locate_config_file ufw/bridge.conf)" >> /etc/ufw/sysctl.conf
fi

if grep -q '^IPV6=' /etc/default/ufw; then
    sed -i "s/^IPV6=.*/IPV6=${W_UFW_IPV6}/" /etc/default/ufw
else
    echo "IPV6=${W_UFW_IPV6}" >> /etc/default/ufw
fi

g_run_silent ufw logging "${W_UFW_LOGGING}"

g_log_info "SSH limit sur le port détecté ${SSH_PORT}/tcp"

w_remove_ufw_marked() {
    local nums n
    mapfile -t nums < <(LANG=C LC_ALL=C ufw status numbered \
        | awk -v open="${W_UFW_SSH_COMMENT_OPEN}" -v lan="${W_UFW_SSH_COMMENT_LAN}" '
            index($0, open) || index($0, lan) {
                if (match($0, /\[[[:space:]]*[0-9]+\]/)) {
                    token = substr($0, RSTART, RLENGTH)
                    gsub(/[^0-9]/, "", token)
                    print token
                }
            }
        ' \
        | sort -nr)
    for n in "${nums[@]+"${nums[@]}"}"; do
        [[ -n "${n}" ]] || continue
        g_run_silent ufw --force delete "${n}"
    done
}

mapfile -t ssh_prefixes < <(ip -o addr show up scope global 2>/dev/null | awk '{print $4}')
if ip -o -6 addr show up scope link 2>/dev/null | grep -q 'fe80:'; then
    ssh_prefixes+=("${W_UFW_LINK_LOCAL}")
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
    if ! LANG=C LC_ALL=C ufw status | grep -qF "${W_UFW_SSH_COMMENT_OPEN}"; then
        g_run_silent ufw limit "${SSH_PORT}/tcp" comment "${W_UFW_SSH_COMMENT_OPEN}"
    fi
    g_log_warn "Aucun préfixe connecté : SSH reste ouvert sur toutes les sources"
else
    w_remove_ufw_marked
    for prefix in "${kept_prefixes[@]}"; do
        g_run_silent ufw limit from "${prefix}" to any port "${SSH_PORT}" proto tcp comment "${W_UFW_SSH_COMMENT_LAN}"
    done
    g_log_success "SSH limité aux préfixes connectés (${kept_prefixes[*]})"
fi

g_run_silent ufw allow in on lo
g_run_silent ufw allow out on lo

g_log_title "Activation UFW"
g_log_info "Activation d'UFW"
g_run_silent ufw --force enable
if ! LANG=C LC_ALL=C ufw status | grep -qw "Status: active"; then
    g_log_error "UFW n'est pas actif après enable : $(LANG=C LC_ALL=C ufw status)"
fi
g_log_success "UFW activé (outgoing ALLOW)"
bash "${G_INSTALL_DIRECTORY}/service/ufw/egress.sh" "${G_INSTALL_DIRECTORY}"
