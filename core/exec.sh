#!/usr/bin/env bash
# Exécution des commandes et des étapes. Pas de politique produit.

run_silent() {
    local cmd_output
    local exit_code=0

    cmd_output=$("$@" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi

    error "$cmd_output"
}

try_silent() {
    local cmd_output
    local exit_code=0

    cmd_output=$("$@" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 && -n "$cmd_output" ]]; then
        debug "$cmd_output"
    fi
    # Toujours 0 : sous set -e un return ≠ 0 tue le script. Unités métier
    # (haveged, rng-tools-debian, …) : run_silent / is-active, pas try_silent.
    return 0
}

run_silent_apt() {
    local cmd_output
    local exit_code=0
    local attempt=0
    local max_attempts=30
    local refreshed=0

    sleep 1

    while [[ $attempt -lt $max_attempts ]]; do
        # stdin fermé et needrestart en automatique : un hook ne peut pas
        # attendre une réponse qui ne s'affiche pas. Les lectures /dev/tty
        # de configure.sh et debconf-set-selections ne passent pas ici.
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

        # Index périmé : le .deb cité n'est plus sur le miroir (404).
        if [[ "${refreshed}" -eq 0 ]] && echo "$cmd_output" | grep -qE '404  Not Found|Failed to fetch|Impossible de récupérer'; then
            refreshed=1
            DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get update </dev/null >/dev/null 2>&1 || true
            continue
        fi

        error "$cmd_output"
    done

    echo ""
    echo ""

    error "Timeout : verrou apt toujours occupé après ${max_attempts} tentatives !" >&2
    exit 1
}

run_steps() {
    local dir_install_path="$1"
    local server_type="$2"
    shift 2
    local -a steps=("$@")

    [[ ${#steps[@]} -eq 0 ]] && {
        error "Aucun step fourni"
        return 1
    }

    [[ -z "$dir_install_path" || ! -d "$dir_install_path" ]] && {
        error "dir_install_path invalide : '$dir_install_path'"
        return 1
    }

    local step full_path step_exit step_log
    for step in "${steps[@]}"; do
        full_path="${dir_install_path}/${step}"
        step_on "Exécution de ${step}"

        if [[ ! -f "$full_path" ]]; then
            error "Fichier introuvable : $full_path"
            exit 1
        fi

        step_exit=0
        step_log=""
        if [[ -n "${HF_LOG_DIR:-}" ]]; then
            step_log="${HF_LOG_DIR}/steps/$(echo "$step" | tr '/' '-').log"
            mkdir -p "${HF_LOG_DIR}/steps"
            set +e
            bash "$full_path" "$dir_install_path" "$server_type" 2>&1 | tee -a "$step_log"
            step_exit=${PIPESTATUS[0]}
            set -e
            hf_log_index_append "${step}" "${step_exit}" "${step_log}"
            hf_publish_repo_logs "${HF_LOG_DIR}"
        else
            set +e
            bash "$full_path" "$dir_install_path" "$server_type"
            step_exit=$?
            set -e
            hf_log_index_append "${step}" "${step_exit}" ""
        fi

        if [[ $step_exit -ne 0 ]]; then
            exit $step_exit
        fi
    done

    return 0
}
