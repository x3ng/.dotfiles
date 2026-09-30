#!/usr/bin/env bash
# Shared functions for install.sh and deploy orchestrator.
# Source this from the dotfiles root or from any deploy.d/ sibling.

set -euo pipefail

# ---- logging ----

log_info()  { echo "  [*] $*"; }
log_warn()  { echo "  [!] $*" >&2; }
log_err()   { echo "  [X] $*" >&2; }

as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ---- dry-run guard ----

is_dry_run() { [[ "${DRY_RUN:-0}" == "1" ]]; }

# ---- user-space symlink helpers ----

# dot_link <src> <dst>
#   Creates a symlink at dst pointing to src.
#   - If a correct symlink already exists, skip.
#   - If a real file/wrong symlink exists, back it up first.
#   - In dry-run mode, only print what would happen.
dot_link() {
    local src="$1" dst="$2"

    if [[ -L "$dst" ]]; then
        if [[ "$(readlink "$dst")" = "$src" ]]; then
            log_info "skip (correct link): $dst"
            return 0
        fi
        log_warn "wrong link at $dst, replacing"
        _backup_target "$dst"
    elif [[ -e "$dst" ]]; then
        log_warn "real file at $dst, backing up"
        _backup_target "$dst"
    fi

    if is_dry_run; then
        log_info "DRY: ln -sf $src $dst"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    if [[ -d "$src" ]]; then
        ln -sfn "$src" "$dst"
    else
        ln -sf "$src" "$dst"
    fi
    log_info "linked: $dst -> $src"
}

# dot_unlink <dst>
#   Removes the symlink at dst. Restores the most recent backup if available.
dot_unlink() {
    local dst="$1"

    if [[ ! -L "$dst" ]]; then
        log_info "skip (not a link): $dst"
        return 0
    fi

    if is_dry_run; then
        log_info "DRY: rm $dst"
        _restore_latest_backup "$dst"
        return 0
    fi

    rm "$dst"
    log_info "removed link: $dst"
    _restore_latest_backup "$dst"
}

# ---- system-space template helpers ----

# dot_template [--mode MODE] <src> <dst> [KEY=VALUE ...]
#   Reads <src> as a template, replaces {{KEY}} placeholders with values,
#   then sudo-installs to <dst> with an explicit mode (default: 0600).
#   If dst already exists, backs it up first.
#   If the calling install.sh is non-interactive and no values are provided
#   via environment, it aborts with guidance.
dot_template() {
    local mode="0600"
    if [[ "${1:-}" == "--mode" ]]; then
        if [[ $# -lt 4 ]]; then
            log_err "dot_template --mode requires MODE, src, and dst"
            return 2
        fi
        mode="$2"
        shift 2
    fi

    if [[ ! "$mode" =~ ^0?[0-7]{3}$ ]]; then
        log_err "invalid file mode: $mode"
        return 2
    fi

    local src="$1" dst="$2"; shift 2

    if is_dry_run; then
        local keys=() pair
        for pair in "$@"; do keys+=("${pair%%=*}"); done
        log_info "DRY: template $src -> $dst (mode: $mode, vars: ${keys[*]})"
        return 0
    fi

    local tmp; tmp="$(mktemp)"
    cp "$src" "$tmp"

    for pair in "$@"; do
        local key="${pair%%=*}" val="${pair#*=}"
        if [[ "$val" == *$'\n'* || "$val" == *$'\r'* ]]; then
            log_err "template value for $key contains a newline"
            rm "$tmp"
            return 2
        fi
        # Escape sed replacement metacharacters so URL query strings remain literal.
        local escaped="${val//\\/\\\\}"
        escaped="${escaped//&/\\&}"
        escaped="${escaped//|/\\|}"
        # Feed the expression on stdin so the value is absent from sed's argv.
        printf 's|{{%s}}|%s|g\n' "$key" "$escaped" | sed -i -f /dev/stdin "$tmp"
    done

    if [[ -e "$dst" ]]; then
        log_warn "file exists at $dst, backing up"
        _backup_target "$dst"
    fi

    as_root install -D -m "$mode" "$tmp" "$dst"
    rm "$tmp"
    log_info "installed: $dst (mode: $mode)"
}

# dot_untemplate <dst>
#   sudo-removes <dst>. Restores the most recent backup if available.
dot_untemplate() {
    local dst="$1"

    if [[ ! -f "$dst" ]]; then
        log_info "skip (not found): $dst"
        return 0
    fi

    if is_dry_run; then
        log_info "DRY: remove $dst as root"
        _restore_latest_backup "$dst"
        return 0
    fi

    as_root rm "$dst"
    log_info "removed: $dst"
    _restore_latest_backup "$dst"
}

# ---- internal helpers ----

_backup_target() {
    local target="$1"
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    if is_dry_run; then
        log_info "DRY: mv $target $backup"
        return 0
    fi
    mv "$target" "$backup"
    log_info "backup: $backup"
}

_restore_latest_backup() {
    local target="$1"
    local latest; latest="$(ls -1t "${target}.backup."* 2>/dev/null | head -1 || true)"
    if [[ -n "$latest" ]]; then
        if is_dry_run; then
            log_info "DRY: mv $latest $target"
        else
            mv "$latest" "$target"
            log_info "restored backup: $target"
        fi
    fi
}
