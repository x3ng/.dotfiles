#!/bin/bash
set -uo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_PATH")")"
DESTINATION="${DESTINATION:-$HOME}"
FILE_LIST="${FILE_LIST:-$DOTFILES_DIR/filelist}"

declare -i success=0 skip=0 error=0
declare -a errors=()

log() {
    local level=$1; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $level: $*" >&2
}

validate_source() {
    local src=$1 path=$2
    if [[ ! -e "$src" ]]; then
        log ERROR "Source file/dir not found: $path"
        errors+=("Source missing: $path")
        return 1
    fi
    return 0
}

validate_target_path() {
    local target=$1 path=$2
    local resolved_target=$(readlink -f "$target" 2>/dev/null || echo "$target")
    local dest_real=$(readlink -f "$DESTINATION")
    
    if [[ -n "$resolved_target" && "$resolved_target" != "$dest_real"* ]]; then
        errors+=("Security check failed: $path (escapes destination)")
        return 1
    fi
    return 0
}

create_backup() {
    local target=$1
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    if mv "$target" "$backup"; then
        log INFO "Backup created: $target -> $backup"
        return 0
    else
        errors+=("Backup failed: $target")
        return 1
    fi
}

handle_existing_target() {
    local target=$1 src=$2 path=$3
    validate_target_path "$target" "$path" || return 1

    if [[ -L "$target" ]]; then
        [[ "$(readlink "$target")" = "$src" ]] && { log INFO "Link exists (correct): $path"; ((skip++)); return 1; }
        log WARNING "Link points to wrong location: $path"
    elif [[ -e "$target" ]]; then
        log WARNING "File/dir exists: $path"
    else
        return 0
    fi

    create_backup "$target" || return 1
    return 0
}

create_symlink() {
    local src=$1 target=$2 path=$3
    mkdir -p "$(dirname "$target")" || { errors+=("Create dir failed: $(dirname "$target")"); return 1; }
    ln -sf "$src" "$target" && { log INFO "Linked: $path"; ((success++)); return 0; }
    errors+=("Link failed: $path")
    return 1
}

process_item() {
    local path=$1
    local src="$DOTFILES_DIR/$path"
    local target="$DESTINATION/$path"

    validate_source "$src" "$path" || { ((error++)); return 1; }
    handle_existing_target "$target" "$src" "$path" || return 1
    create_symlink "$src" "$target" "$path" || ((error++))
}

main() {
    log INFO "Starting dotfiles linking..."
    log INFO "Dotfiles dir: $DOTFILES_DIR | Destination: $DESTINATION | Config: $FILE_LIST"
    echo

    if [[ ! -f "$FILE_LIST" ]]; then
        log ERROR "Config file not found: $FILE_LIST"
        exit 1
    elif [[ ! -r "$FILE_LIST" ]]; then
        log ERROR "Config file not readable: $FILE_LIST"
        exit 1
    elif [[ ! -s "$FILE_LIST" ]]; then
        log WARNING "Config file is empty: $FILE_LIST"
        exit 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        local path=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$path" ]] && continue
        process_item "$path"
    done < "$FILE_LIST"

    echo
    log INFO "Success: $success | Skipped: $skip | Errors: $error"
    
    if [[ $error -gt 0 ]]; then
        echo
        log ERROR "Error details:"
        for msg in "${errors[@]}"; do echo "  - $msg"; done
    fi

    [[ $error -eq 0 ]] && log INFO "All done successfully!" || log ERROR "Completed with errors."
    exit $((error > 0 ? 1 : 0))
}

main "$@"
