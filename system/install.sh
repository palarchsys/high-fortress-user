#!/usr/bin/env bash
# =============================================================================
# File       : system/install.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

G_INSTALL_DIRECTORY="${1}"
export G_INSTALL_DIRECTORY

# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${G_INSTALL_DIRECTORY}/core/lib.sh"
source "${G_INSTALL_DIRECTORY}/config/global.conf"

g_require_root
g_get_current_user

g_log_title "Arborescence projet"
g_log_info "Création de ${G_CONFIG_BASE_DIRECTORY}"
g_ensure_directory "${G_CONFIG_BASE_DIRECTORY}" 755
g_ensure_directory "${G_SECRET_DIRECTORY}" 700
g_log_success "Répertoires projet prêts"

g_log_title "Outils de base"
g_log_info "Installation des outils de base"
g_run_silent_apt install -y apt-listchanges needrestart apt-show-versions \
    openssh-server openssh-client curl openssl rsync ca-certificates \
    jq gnupg gettext-base lsb-release
g_log_success "Outils de base installés"

g_log_title "Dépôt Lynis CISOfy"
g_log_info "Création de /etc/apt/keyrings"
g_ensure_directory /etc/apt/keyrings 755

LYNIS_KEY="/etc/apt/keyrings/cisofy-software.gpg"
LYNIS_LIST="/etc/apt/sources.list.d/lynis.list"

if [[ ! -f "${LYNIS_KEY}" ]]; then
    g_log_info "Téléchargement de la clé GPG Lynis"
    curl -fsSL https://packages.cisofy.com/keys/cisofy-software-public.key | gpg --dearmor -o "${LYNIS_KEY}"
    chmod 644 "${LYNIS_KEY}"
    chown root:root "${LYNIS_KEY}"
    g_log_success "Clé GPG Lynis installée"
fi

g_log_info "Configuration du dépôt Lynis"
tee "${LYNIS_LIST}" > /dev/null << EOF
deb [arch=$(dpkg --print-architecture) signed-by=${LYNIS_KEY}] https://packages.cisofy.com/community/lynis/deb/ stable main
EOF
chmod 644 "${LYNIS_LIST}"
g_log_success "Dépôt Lynis configuré (sources Ubuntu non modifiées)"

g_log_title "Ubuntu Pro"

g_log_info "Installation du client Ubuntu Pro"
g_run_silent_apt install -y ubuntu-pro-client

g_log_info "Contrôle de l'attachement Ubuntu Pro"
if g_check_ubuntu_pro; then
    g_log_success "Ubuntu Pro : déjà attachée"
else
    if [[ -z "${G_UBUNTU_PRO_TOKEN// /}" ]]; then
        g_log_error "Ubuntu Pro : jeton manquant dans secrets.conf. Relancer : bash ${G_INSTALL_DIRECTORY}/hf configure"
    fi
    g_log_info "Attachement d'Ubuntu Pro"
    attach_out=$(pro attach "${G_UBUNTU_PRO_TOKEN}" 2>&1) && attach_rc=0 || attach_rc=$?
    if [[ "${attach_rc}" -eq 0 ]]; then
        g_log_success "Ubuntu Pro : machine attachée"
    elif echo "${attach_out}" | grep -qiE 'already attached'; then
        g_log_success "Ubuntu Pro : déjà attachée"
    else
        g_log_error "Ubuntu Pro attach a échoué (obligatoire) : ${attach_out}"
    fi
fi

if ! g_check_ubuntu_pro; then
    g_log_error "Ubuntu Pro : la machine n'est pas attachée après pro attach."
fi

if g_check_ubuntu_lts; then
    for svc in esm-infra esm-apps; do
        g_log_info "Activation d'Ubuntu Pro (${svc})"
        en_out=$(pro enable "${svc}" --assume-yes 2>&1) && en_rc=0 || en_rc=$?
        if [[ "${en_rc}" -eq 0 ]] || echo "${en_out}" | grep -qiE 'already enabled'; then
            g_log_success "Ubuntu Pro : ${svc} activé"
        fi
        if [[ "${en_rc}" -ne 0 ]] && ! echo "${en_out}" | grep -qiE 'already enabled'; then
            g_log_warn "Ubuntu Pro : ${svc} non activé, installation poursuivie"
            g_log_debug "${en_out}"
        fi
    done

    g_log_info "Activation de Livepatch"
    lp_out=$(pro enable livepatch --assume-yes 2>&1) && lp_rc=0 || lp_rc=$?
    if [[ "${lp_rc}" -eq 0 ]] || echo "${lp_out}" | grep -qiE 'already enabled'; then
        g_log_success "Ubuntu Pro : livepatch activé"
    fi
    if [[ "${lp_rc}" -ne 0 ]] && ! echo "${lp_out}" | grep -qiE 'already enabled'; then
        g_log_warn "Ubuntu Pro : livepatch non activé, installation poursuivie"
        g_log_debug "${lp_out}"
    fi
else
    g_log_info "Version intermédiaire : esm-infra, esm-apps et Livepatch ne sont pas activés."
fi
g_log_info "Installation d'Ubuntu Pro"
g_log_success "Ubuntu Pro installé"

g_log_title "Multiarch i386"

if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
    g_log_info "Contrôle de l'architecture i386"
    if dpkg --print-foreign-architectures | grep -qx 'i386'; then
        g_log_success "Architecture i386 déjà activée"
    else
        g_log_info "Activation de l'architecture i386"
        g_run_silent dpkg --add-architecture i386
        g_log_success "Architecture i386 activée"
    fi
else
    g_log_info "Architecture $(dpkg --print-architecture) — i386 non requis hors amd64"
fi

g_log_title "Mise à jour système"
g_log_info "Mise à jour du système"
g_run_silent_apt update
g_run_silent_apt upgrade -y
g_log_success "Mise à jour terminée"

g_log_title "Comptabilité et PAM (Lynis ACCT / AUTH)"

g_log_info "Installation de la comptabilité et de PAM"
g_run_silent_apt install -y acct sysstat libpam-pwquality
if [[ -f /etc/default/sysstat ]]; then
    sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
fi
g_run_optional systemctl enable --now sysstat
g_run_optional systemctl enable --now acct
g_log_success "Paquets acct, sysstat et libpam-pwquality installés"

g_log_title "Entropie (haveged + rng-tools-debian)"
g_log_info "Installation de haveged et de rng-tools-debian"
g_run_silent_apt install -y rng-tools-debian haveged
g_run_silent systemctl enable --now haveged
if ! systemctl is-active --quiet haveged; then
    g_log_warn "haveged installé mais inactif"
else
    g_log_success "haveged activé"
fi

g_log_info "Configuration de rng-tools-debian (HWRNG si présent, sinon haveged)"
{
    echo "# Liltress Workstation — Lynis CRYP-8004"
    echo "HRNGDEVICE=/dev/hwrng"
} > /etc/default/rng-tools-debian
chmod 644 /etc/default/rng-tools-debian
g_run_optional systemctl enable rng-tools-debian
g_run_optional systemctl restart rng-tools-debian.service
if systemctl is-active --quiet rng-tools-debian && pgrep -x rngd >/dev/null; then
    g_log_success "rngd activé"
else
    g_log_info "Pas de HWRNG exploitable — entropie via haveged (OK desktop)"
fi

g_log_title "Lynis"
g_log_info "Installation de Lynis"
g_run_silent_apt install -y lynis --no-install-recommends
g_log_success "Lynis installé"
