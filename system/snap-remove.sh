#!/usr/bin/env bash
# =============================================================================
# Fichier    : system/snap-remove.sh
# Créé le    : 2026-09-28
# Créateur   : palarchsys
#
# Rôle
#   Retire les snaps Firefox et Thunderbird. snapd reste installé.
# =============================================================================

# Le reste du bureau s'appuie sur snapd (thèmes, boutique, montages).
# Seuls Firefox et Thunderbird en sont retirés : le navigateur du poste
# est Brave, le courrier vient du dépôt Mozilla. Le paquet Ubuntu de
# chacun est une enveloppe qui réinstallerait le snap ; il est purgé,
# et firefox est bloqué. snapd n'est ni purgé ni interdit.
#
# Sur une relance, ClamAV est suspendu le temps du retrait : le
# démontage du dossier privé sous /tmp échoue s'il est surveillé.
# =============================================================================
DIR_INSTALL_PATH="${1}"
export DIR_INSTALL_PATH
SERVER_TYPE="${2}"
export SERVER_TYPE

source "${DIR_INSTALL_PATH}/core/lib.sh"
source "${DIR_INSTALL_PATH}/global.conf"
require_root
detect_current_user

HFU_ONACCESS_PAUSED=0
hfu_daemon_reload() {
    systemctl daemon-reload >/dev/null 2>&1 || true
}
hfu_resume_onaccess() {
    [[ "${HFU_ONACCESS_PAUSED:-0}" -eq 1 ]] || return 0
    HFU_ONACCESS_PAUSED=0
    local unit
    hfu_daemon_reload
    for unit in clamav-clamonacc.service clamonacc.service; do
        if systemctl cat "${unit}" >/dev/null 2>&1; then
            systemctl start "${unit}" >/dev/null 2>&1 || true
            return 0
        fi
    done
}
hfu_pause_onaccess() {
    local unit
    hfu_daemon_reload
    for unit in clamav-clamonacc.service clamonacc.service; do
        if systemctl is-active --quiet "${unit}" 2>/dev/null; then
            info "Suspension de ${unit}"
            timeout 20 systemctl stop "${unit}" >/dev/null 2>&1 || true
            HFU_ONACCESS_PAUSED=1
        fi
    done
    trap hfu_resume_onaccess EXIT
}

title "Retrait des snaps Firefox et Thunderbird"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

hfu_pause_onaccess
if [[ "${HFU_ONACCESS_PAUSED}" -eq 1 ]]; then
    info "Surveillance ClamAV en pause le temps de démonter ces deux snaps."
fi

repair_log="${HF_LOG_DIR:-/var/log/high-fortress-user}/snap-remove.log"
mkdir -p "$(dirname "${repair_log}")"

# Un passage précédent a pu interdire snapd. On retire cet interdit
# avant toute autre action, pour que le paquet puisse rester ou revenir.
rm -f /etc/apt/preferences.d/no-snap.pref
apt-mark unhold snapd >/dev/null 2>&1 || true
if ! dpkg-query -W -f '${Status}' snapd 2>/dev/null | grep -q 'install ok'; then
    info "Réinstallation de snapd."
    run_silent_apt install -y snapd
fi

for name in firefox thunderbird; do
    if ! command -v snap >/dev/null 2>&1 || ! snap list "${name}" >/dev/null 2>&1; then
        info "Snap ${name} absent"
        continue
    fi
    info "Arrêt du snap ${name}"
    timeout 30 snap stop "${name}" </dev/null >>"${repair_log}" 2>&1 || true
    pkill -f "/snap/${name}/" >/dev/null 2>&1 || true
    info "Retrait du snap ${name}"
    if ! timeout 90 snap remove --purge "${name}" </dev/null >>"${repair_log}" 2>&1; then
        warn "Retrait du snap ${name} non terminé. Détail : ${repair_log}"
    else
        success "Snap ${name} retiré"
    fi
done

for pkg in firefox thunderbird; do
    ver="$(dpkg-query -W -f '${Version}' "${pkg}" 2>/dev/null || true)"
    if [[ "${ver}" == *snap* ]]; then
        info "Purge du paquet de transition ${pkg}"
        run_silent_apt purge -y "${pkg}"
        success "Paquet de transition ${pkg} retiré"
    fi
done
if apt-mark showhold 2>/dev/null | grep -qx firefox; then
    info "Paquet firefox déjà bloqué"
else
    apt-mark hold firefox >/dev/null
    success "Paquet firefox bloqué"
fi

hfu_resume_onaccess
success "snapd conservé, Firefox et Thunderbird snaps retirés"
