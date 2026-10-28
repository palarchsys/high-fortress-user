#!/usr/bin/env bash
# =============================================================================
# File       : core/launch.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

g_launch() {
    local root="$1"
    local cmd="${2:-help}"
    shift 2 || true
    case "${cmd}" in
        configure)
            exec bash "${root}/scripts/configure.sh" "$@"
            ;;
        check)
            exec bash "${root}/scripts/configure.sh" --check "$@"
            ;;
        run)
            exec bash "${root}/scripts/run.sh" "$@"
            ;;
        lynis)
            exec bash "${root}/core/lynis.sh" "${root}" "$@"
            ;;
        logs)
            exec bash "${root}/system/collect-logs.sh" "$@"
            ;;
        help|-h|--help)
            cat << EOF
Usage : ${root}/liltress <commande>

  configure   prépare global.conf et secrets.conf
  check       vérifie ces deux fichiers
  run         installe (root)
  lynis       audit Lynis (root)
  logs        copie les journaux
  help        cette aide
EOF
            if [[ -f "${root}/verify/workstation.sh" ]]; then
                cat << 'EOF'

Vérification :

  sudo bash verify/alerts.sh [--no-send]
  sudo bash verify/workstation.sh "$PWD"
  sudo bash verify/boot.sh
  sudo bash verify/chkrootkit-fp.sh
  sudo bash /opt/liltress-workstation/bin/scan-skip.sh list|add|del
EOF
            fi
            if [[ -f "${root}/verify/matrix.sh" ]]; then
                cat << 'EOF'

  sudo ./liltress configure --basic   nom du projet + domaine ; le reste est calculé
  sudo ./liltress configure --avance  toutes les questions, sauf le profil serveur

Vérification :

  sudo bash verify/alerts.sh [--no-send]
  sudo bash verify/matrix.sh "$PWD" MATRIX
  sudo bash verify/livekit.sh "$PWD" LIVEKIT
  sudo bash verify/wireguard.sh "$PWD" WIREGUARD
EOF
            fi
            ;;
        *)
            printf 'commande inconnue : %s\n' "${cmd}" >&2
            printf 'Usage : %s/liltress help\n' "${root}" >&2
            exit 2
            ;;
    esac
}
