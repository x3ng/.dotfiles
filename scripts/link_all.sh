#!/usr/bin/env bash
# Symlinks dotfiles from this repo into $HOME.
# Usage: ./scripts/link_all.sh <filelist>
set -uo pipefail

# ---- paths ----
SCRIPT_PATH="$(readlink -f "$0")"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_PATH")")"
DESTINATION="${DESTINATION:-$HOME}"
FILE_LIST="${1:-}"

# ---- state ----
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

# Ensure the resolved target is under $DESTINATION — prevents
# accidental writes outside home from misconfigured filelists.
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

# Move an existing file/dir to a timestamped backup before overwriting.
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

# Check what's already at the target path: correct link → skip,
# wrong link or real file → backup first.
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

# Each line: <src> [<dst>] — if dst is omitted, src is used as dst.
process_item() {
    local src=$1 dst=$2
    dst="${dst:-$src}"
    local src_full="$DOTFILES_DIR/$src"
    local target="$DESTINATION/$dst"

    validate_source "$src_full" "$src" || { ((error++)); return 1; }
    handle_existing_target "$target" "$src_full" "$src" || return 1
    create_symlink "$src_full" "$target" "$src" || ((error++))
}

main() {
    log INFO "Starting dotfiles linking..."
    log INFO "Dotfiles dir: $DOTFILES_DIR | Destination: $DESTINATION"

    if [[ -z "$FILE_LIST" ]]; then
        log ERROR "Usage: $0 <filelist>  (e.g. hosts/desktop)"
        exit 1
    fi

    log INFO "Config: $FILE_LIST"
    echo

    if [[ ! -f "$FILE_LIST" ]]; then
        log ERROR "File not found: $FILE_LIST"
        exit 1
    elif [[ ! -r "$FILE_LIST" ]]; then
        log ERROR "File not readable: $FILE_LIST"
        exit 1
    elif [[ ! -s "$FILE_LIST" ]]; then
        log WARNING "File is empty: $FILE_LIST"
        exit 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip blank lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Trim leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        # Split into src and optional dst
        process_item $line
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
