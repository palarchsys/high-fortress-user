#!/usr/bin/env bash
# =============================================================================
# File       : core/fs.sh
# Updated at : 2026-10-05
# Creator    : palarchsys
# =============================================================================

add_line_if_missing() {
    local file="$1"
    local line="$2"
    local comment="${3:-}"
    if ! grep -qF "$line" "$file" 2>/dev/null; then
        [[ -n "$comment" ]] && echo "$comment" >> "$file"
        echo "$line" >> "$file"
    fi
}

backup_file_once() {
    local file="$1"
    local backup="${file}.bak"
    [[ -f "$file" ]] || return 0
    [[ -f "$backup" ]] && return 0
    info "Création de la copie de sauvegarde de ${file}"
    cp -a "$file" "$backup" && success "Copie de sauvegarde créée : ${backup}"
}

ensure_dir() {
    local mode="700"
    local user="root"
    local group="root"
    local dirs=()

    while [ $# -gt 0 ]; do
        case "$1" in
            [0-9]*)
                mode="$1"
                shift
                break
                ;;
            *)
                dirs+=("$1")
                shift
                ;;
        esac
    done

    if [ $# -ge 1 ]; then
        user="$1"
    fi
    if [ $# -ge 2 ]; then
        group="$2"
    fi

    local dir effective_user effective_group
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod "$mode" "$dir"

        effective_user="$user"
        effective_group="$group"

        if ! id -u "$effective_user" >/dev/null 2>&1; then
            effective_user="root"
        fi
        if ! getent group "$effective_group" >/dev/null 2>&1; then
            effective_group="root"
        fi

        chown "${effective_user}:${effective_group}" "$dir" 2>/dev/null || true
    done
}

user_exists() {
    local user="$1"
    id "$user" >/dev/null 2>&1
}
