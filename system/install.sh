#!/usr/bin/env bash
# =============================================================================
# File       : system/install.sh
# Updated at : 2026-10-15
# Creator    : palarchsys
# =============================================================================

HF_INSTALL_DIRECTORY="${1}"
export HF_INSTALL_DIRECTORY

# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${HF_INSTALL_DIRECTORY}/core/lib.sh"
source "${HF_INSTALL_DIRECTORY}/config/global.conf"

hf_require_root
hf_get_current_user

hf_log_title "Arborescence projet"
hf_log_info "Création de ${HF_CONFIG_BASE_DIRECTORY}"
hf_ensure_directory "${HF_CONFIG_BASE_DIRECTORY}" 755
hf_ensure_directory "${HF_SECRET_DIRECTORY}" 700
hf_log_success "Répertoires projet prêts"

hf_log_title "Outils de base"
hf_log_info "Installation des outils de base (sources APT inchangées)"
hf_run_silent_apt install -y apt-listchanges needrestart apt-show-versions \
    openssh-server openssh-client curl openssl rsync ca-certificates \
    jq gnupg gettext-base lsb-release
hf_log_success "Outils de base installés"

hf_log_title "Dépôt Lynis CISOfy"
hf_log_info "Création de /etc/apt/keyrings"
hf_ensure_directory /etc/apt/keyrings 755

LYNIS_KEY="/etc/apt/keyrings/cisofy-software.gpg"
LYNIS_LIST="/etc/apt/sources.list.d/lynis.list"

if [[ ! -f "${LYNIS_KEY}" ]]; then
    hf_log_info "Téléchargement de la clé GPG Lynis"
    curl -fsSL https://packages.cisofy.com/keys/cisofy-software-public.key | gpg --dearmor -o "${LYNIS_KEY}"
    chmod 644 "${LYNIS_KEY}"
    chown root:root "${LYNIS_KEY}"
    hf_log_success "Clé GPG Lynis installée"
fi

hf_log_info "Configuration du dépôt Lynis"
tee "${LYNIS_LIST}" > /dev/null << EOF
deb [arch=$(dpkg --print-architecture) signed-by=${LYNIS_KEY}] https://packages.cisofy.com/community/lynis/deb/ stable main
EOF
chmod 644 "${LYNIS_LIST}"
hf_log_success "Dépôt Lynis configuré (sources Ubuntu non modifiées)"

hf_log_title "Ubuntu Pro"

hf_log_info "Installation du client Ubuntu Pro"
hf_run_silent_apt install -y ubuntu-pro-client

hf_log_info "Contrôle de l'attachement Ubuntu Pro"
if hf_check_ubuntu_pro; then
    hf_log_success "Ubuntu Pro : déjà attachée"
else
    if [[ -z "${HF_UBUNTU_PRO_TOKEN// /}" ]]; then
        hf_log_error "Ubuntu Pro : jeton manquant dans secrets.conf. Relancer : bash ${HF_INSTALL_DIRECTORY}/hf configure"
    fi
    hf_log_info "Attachement d'Ubuntu Pro"
    attach_out=$(pro attach "${HF_UBUNTU_PRO_TOKEN}" 2>&1) && attach_rc=0 || attach_rc=$?
    if [[ "${attach_rc}" -eq 0 ]]; then
        hf_log_success "Ubuntu Pro : machine attachée"
    elif echo "${attach_out}" | grep -qiE 'already attached'; then
        hf_log_success "Ubuntu Pro : déjà attachée"
    else
        hf_log_error "Ubuntu Pro attach a échoué (obligatoire) : ${attach_out}"
    fi
fi

if ! hf_check_ubuntu_pro; then
    hf_log_error "Ubuntu Pro : la machine n'est pas attachée après pro attach."
fi

for svc in esm-infra esm-apps; do
    hf_log_info "Activation d'Ubuntu Pro (${svc})"
    en_out=$(pro enable "${svc}" --assume-yes 2>&1) && en_rc=0 || en_rc=$?
    if [[ "${en_rc}" -eq 0 ]] || echo "${en_out}" | grep -qiE 'already enabled'; then
        hf_log_success "Ubuntu Pro : ${svc} activé"
    else
        hf_log_error "Ubuntu Pro : impossible d'activer ${svc} (obligatoire) : ${en_out}"
    fi
done

hf_log_info "Activation de Livepatch"
lp_out=$(pro enable livepatch --assume-yes 2>&1) && lp_rc=0 || lp_rc=$?
if [[ "${lp_rc}" -eq 0 ]] || echo "${lp_out}" | grep -qiE 'already enabled'; then
    hf_log_success "Ubuntu Pro : livepatch activé"
else
    hf_log_error "Ubuntu Pro : livepatch obligatoire, activation échouée : ${lp_out}"
fi
hf_log_info "Installation d'Ubuntu Pro"
hf_log_success "Ubuntu Pro installé (attaché + ESM + livepatch)"

hf_log_title "Multiarch i386 (Steam)"

if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
    hf_log_info "Contrôle de l'architecture i386"
    if dpkg --print-foreign-architectures | grep -qx 'i386'; then
        hf_log_success "Architecture i386 déjà activée"
    else
        hf_log_info "Activation de l'architecture i386"
        hf_run_silent dpkg --add-architecture i386
        hf_log_success "Architecture i386 activée (bibliothèques Steam / Proton)"
    fi
else
    hf_log_info "Architecture $(dpkg --print-architecture) — i386 non requis hors amd64"
fi

hf_log_title "Mise à jour système"
hf_log_info "Mise à jour du système (dépôts existants conservés)"
hf_run_silent_apt update
hf_run_silent_apt upgrade -y
hf_log_success "Mise à jour terminée"

hf_log_title "Comptabilité et PAM (Lynis ACCT / AUTH)"

hf_log_info "Installation de la comptabilité et de PAM"
hf_run_silent_apt install -y acct sysstat libpam-pwquality
if [[ -f /etc/default/sysstat ]]; then
    sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
fi
hf_run_optional systemctl enable --now sysstat
hf_run_optional systemctl enable --now acct
hf_log_success "Paquets acct, sysstat et libpam-pwquality installés"

hf_log_title "Entropie (haveged + rng-tools-debian)"
hf_log_info "Installation de haveged et de rng-tools-debian"
hf_run_silent_apt install -y rng-tools-debian haveged
hf_run_silent systemctl enable --now haveged
if ! systemctl is-active --quiet haveged; then
    hf_log_warn "haveged installé mais inactif"
else
    hf_log_success "haveged activé"
fi

hf_log_info "Configuration de rng-tools-debian (HWRNG si présent, sinon haveged)"
{
    echo "# High-Fortress User — Lynis CRYP-8004"
    echo "HRNGDEVICE=/dev/hwrng"
} > /etc/default/rng-tools-debian
chmod 644 /etc/default/rng-tools-debian
hf_run_optional systemctl enable rng-tools-debian
hf_run_optional systemctl restart rng-tools-debian.service
if systemctl is-active --quiet rng-tools-debian && pgrep -x rngd >/dev/null; then
    hf_log_success "rngd activé"
else
    hf_log_info "Pas de HWRNG exploitable — entropie via haveged (OK desktop)"
fi

hf_log_title "Lynis"
hf_log_info "Installation de Lynis"
hf_run_silent_apt install -y lynis --no-install-recommends
hf_log_success "Lynis installé"
