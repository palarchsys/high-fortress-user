#!/usr/bin/env bash
# =============================================================================
# File       : core/exec.sh
# Updated at : 2026-10-28
# Creator    : palarchsys
# =============================================================================

g_run_silent() {
    local cmd_output
    local exit_code=0

    cmd_output=$("$@" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi

    g_log_error "$cmd_output"
}

g_run_quiet() {
    local cmd_output
    local exit_code=0

    cmd_output=$("$@" 2>&1) || exit_code=$?
    if [[ -n "${G_LOG_FILE:-}" && -n "${cmd_output}" ]]; then
        printf '%s\n' "${cmd_output}" >> "${G_LOG_FILE}"
    fi
    if [[ "${exit_code}" -ne 0 ]]; then
        g_log_error "${cmd_output:-commande échouée (rc=${exit_code})}"
    fi
}

g_run_optional() {
    local cmd_output
    local exit_code=0

    cmd_output=$("$@" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 && -n "$cmd_output" ]]; then
        g_log_debug "$cmd_output"
    fi

    return 0
}

g_run_silent_apt() {
    local cmd_output
    local exit_code=0
    local attempt=0
    local max_attempts=30
    local refreshed=0

    sleep 1

    while [[ $attempt -lt $max_attempts ]]; do

        exit_code=0
        cmd_output=$(DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get "$@" </dev/null 2>&1) || exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            return 0
        fi

        if echo "$cmd_output" | grep -qE "Could not get lock|verrou|lock-frontend|unattended-upgr"; then
            attempt=$((attempt + 1))
            sleep 2
            continue
        fi

        if [[ "${refreshed}" -eq 0 ]] && echo "$cmd_output" | grep -qE '404  Not Found|Failed to fetch|Impossible de récupérer'; then
            refreshed=1
            DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get update </dev/null >/dev/null 2>&1 || true
            continue
        fi

        g_log_error "$cmd_output"
    done

    echo ""
    echo ""

    g_log_error "Timeout : verrou apt toujours occupé après ${max_attempts} tentatives !" >&2
    exit 1
}

g_run_step() {
    local dir_install_path="$1"
    local server_type=""
    shift

    if [[ $# -gt 0 ]]; then
        case "$1" in
            *.sh) ;;
            *)
                server_type="$1"
                shift
                ;;
        esac
    fi
    local -a steps=("$@")

    [[ ${#steps[@]} -eq 0 ]] && {
        g_log_error "Aucun step fourni"
        return 1
    }

    [[ -z "$dir_install_path" || ! -d "$dir_install_path" ]] && {
        g_log_error "dir_install_path invalide : '$dir_install_path'"
        return 1
    }

    local step full_path step_exit step_log
    for step in "${steps[@]}"; do
        full_path="${dir_install_path}/${step}"
        g_set_step_visible "Exécution de ${step}"

        if [[ ! -f "$full_path" ]]; then
            g_log_error "Fichier introuvable : $full_path"
            exit 1
        fi

        step_exit=0
        step_log=""
        if [[ -n "${G_LOG_DIR:-}" ]]; then
            step_log="${G_LOG_DIR}/steps/$(echo "$step" | tr '/' '-').log"
            mkdir -p "${G_LOG_DIR}/steps"
            set +e
            bash "$full_path" "$dir_install_path" "$server_type" 2>&1 | tee -a "$step_log"
            step_exit=${PIPESTATUS[0]}
            set -e
            g_log_index_append "${step}" "${step_exit}" "${step_log}"
            g_publish_repo_logs "${G_LOG_DIR}"
        else
            set +e
            bash "$full_path" "$dir_install_path" "$server_type"
            step_exit=$?
            set -e
            g_log_index_append "${step}" "${step_exit}" ""
        fi

        if [[ $step_exit -ne 0 ]]; then
            exit $step_exit
        fi
    done

    return 0
}
