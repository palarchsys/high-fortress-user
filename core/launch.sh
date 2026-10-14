#!/usr/bin/env bash
# =============================================================================
# File       : core/launch.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

hf_launch() {
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
Usage : ${root}/hf <commande>

  configure   prépare global.conf et secrets.conf
  check       vérifie ces deux fichiers
  run         installe (root)
  lynis       audit Lynis (root)
  logs        copie les journaux
  help        cette aide
EOF
            ;;
        *)
            printf 'commande inconnue : %s\n' "${cmd}" >&2
            printf 'Usage : %s/hf help\n' "${root}" >&2
            exit 2
            ;;
    esac
}
