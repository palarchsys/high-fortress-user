#!/usr/bin/env bash
# =============================================================================
# File       : system/install.sh
# Updated at : 2026-10-07
# Creator    : palarchsys
# =============================================================================

DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH

# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly DIR_SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/config/global.conf"

require_root
detect_current_user

title "Arborescence projet"
info "Création de ${CONFIG_BASE_DIR}"
ensure_dir "${CONFIG_BASE_DIR}" 755
ensure_dir "${SECRETS_DIR}" 700
success "Répertoires projet prêts"

title "Outils de base"
info "Installation des outils de base (sources APT inchangées)"
run_silent_apt install -y apt-listchanges needrestart apt-show-versions \
    openssh-server openssh-client curl openssl rsync ca-certificates \
    jq gnupg gettext-base lsb-release
success "Outils de base installés"

title "Dépôt Lynis CISOfy"
info "Création de /etc/apt/keyrings"
ensure_dir /etc/apt/keyrings 755

LYNIS_KEY="/etc/apt/keyrings/cisofy-software.gpg"
LYNIS_LIST="/etc/apt/sources.list.d/lynis.list"

if [[ ! -f "${LYNIS_KEY}" ]]; then
    info "Téléchargement de la clé GPG Lynis"
    curl -fsSL https://packages.cisofy.com/keys/cisofy-software-public.key | gpg --dearmor -o "${LYNIS_KEY}"
    chmod 644 "${LYNIS_KEY}"
    chown root:root "${LYNIS_KEY}"
    success "Clé GPG Lynis installée"
fi

info "Configuration du dépôt Lynis"
tee "${LYNIS_LIST}" > /dev/null << EOF
deb [arch=$(dpkg --print-architecture) signed-by=${LYNIS_KEY}] https://packages.cisofy.com/community/lynis/deb/ stable main
EOF
chmod 644 "${LYNIS_LIST}"
success "Dépôt Lynis configuré (sources Ubuntu non modifiées)"

title "Ubuntu Pro"

info "Installation du client Ubuntu Pro"
run_silent_apt install -y ubuntu-pro-client

info "Contrôle de l'attachement Ubuntu Pro"
if ubuntu_pro_attached; then
    success "Ubuntu Pro : déjà attachée"
else
    if [[ -z "${UBUNTU_PRO_TOKEN// /}" ]]; then
        error "Ubuntu Pro : jeton manquant dans secrets.conf. Relancer : bash ${DIR_INSTALL_PATH}/hf configure"
    fi
    info "Attachement d'Ubuntu Pro"
    attach_out=$(pro attach "${UBUNTU_PRO_TOKEN}" 2>&1) && attach_rc=0 || attach_rc=$?
    if [[ "${attach_rc}" -eq 0 ]]; then
        success "Ubuntu Pro : machine attachée"
    elif echo "${attach_out}" | grep -qiE 'already attached'; then
        success "Ubuntu Pro : déjà attachée"
    else
        error "Ubuntu Pro attach a échoué (obligatoire) : ${attach_out}"
    fi
fi

if ! ubuntu_pro_attached; then
    error "Ubuntu Pro : la machine n'est pas attachée après pro attach."
fi

for svc in esm-infra esm-apps; do
    info "Activation d'Ubuntu Pro (${svc})"
    en_out=$(pro enable "${svc}" --assume-yes 2>&1) && en_rc=0 || en_rc=$?
    if [[ "${en_rc}" -eq 0 ]] || echo "${en_out}" | grep -qiE 'already enabled'; then
        success "Ubuntu Pro : ${svc} activé"
    else
        error "Ubuntu Pro : impossible d'activer ${svc} (obligatoire) : ${en_out}"
    fi
done

info "Activation de Livepatch"
lp_out=$(pro enable livepatch --assume-yes 2>&1) && lp_rc=0 || lp_rc=$?
if [[ "${lp_rc}" -eq 0 ]] || echo "${lp_out}" | grep -qiE 'already enabled'; then
    success "Ubuntu Pro : livepatch activé"
else
    error "Ubuntu Pro : livepatch obligatoire, activation échouée : ${lp_out}"
fi
info "Installation d'Ubuntu Pro"
success "Ubuntu Pro installé (attaché + ESM + livepatch)"

title "Multiarch i386 (Steam)"

if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
    info "Contrôle de l'architecture i386"
    if dpkg --print-foreign-architectures | grep -qx 'i386'; then
        success "Architecture i386 déjà activée"
    else
        info "Activation de l'architecture i386"
        run_silent dpkg --add-architecture i386
        success "Architecture i386 activée (bibliothèques Steam / Proton)"
    fi
else
    info "Architecture $(dpkg --print-architecture) — i386 non requis hors amd64"
fi

title "Mise à jour système"
info "Mise à jour du système (dépôts existants conservés)"
run_silent_apt update
run_silent_apt upgrade -y
success "Mise à jour terminée"

title "Comptabilité et PAM (Lynis ACCT / AUTH)"

info "Installation de la comptabilité et de PAM"
run_silent_apt install -y acct sysstat libpam-pwquality
if [[ -f /etc/default/sysstat ]]; then
    sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
fi
try_silent systemctl enable --now sysstat
try_silent systemctl enable --now acct
success "Paquets acct, sysstat et libpam-pwquality installés"

title "Entropie (haveged + rng-tools-debian)"
info "Installation de haveged et de rng-tools-debian"
run_silent_apt install -y rng-tools-debian haveged
run_silent systemctl enable --now haveged
if ! systemctl is-active --quiet haveged; then
    warn "haveged installé mais inactif"
else
    success "haveged activé"
fi

info "Configuration de rng-tools-debian (HWRNG si présent, sinon haveged)"
{
    echo "# High-Fortress User — Lynis CRYP-8004"
    echo "HRNGDEVICE=/dev/hwrng"
} > /etc/default/rng-tools-debian
chmod 644 /etc/default/rng-tools-debian
try_silent systemctl enable rng-tools-debian
try_silent systemctl restart rng-tools-debian.service
if systemctl is-active --quiet rng-tools-debian && pgrep -x rngd >/dev/null; then
    success "rngd activé"
else
    info "Pas de HWRNG exploitable — entropie via haveged (OK desktop)"
fi

title "Lynis"
info "Installation de Lynis"
run_silent_apt install -y lynis --no-install-recommends
success "Lynis installé"
