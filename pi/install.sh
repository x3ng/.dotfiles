#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

PREFIX="${PI_AGENT_HOME:-$HOME/.pi/agent}"

# Dotfiles only manages Pi's global declarative settings. The file is copied,
# not linked, because Pi writes runtime keys such as lastChangelogVersion.
MANAGED_ITEM="settings.json"

LEGACY_LINKS=(
  AGENTS.md
  agents
  skills
  prompts
  subagents.json
  pi-goal.json
  extensions
  themes
)

ensure_agent_dir() {
  if [[ -L "$PREFIX" ]]; then
    log_warn "$PREFIX is a symlink, removing it so Pi runtime state stays outside dotfiles"
    if ! is_dry_run; then
      rm "$PREFIX"
    fi
  fi

  if is_dry_run; then
    log_info "DRY: mkdir -p $PREFIX"
  else
    mkdir -p "$PREFIX"
  fi
}

cleanup_legacy_links() {
  local item dst target
  for item in "${LEGACY_LINKS[@]}"; do
    dst="$PREFIX/$item"
    if [[ ! -L "$dst" ]]; then
      continue
    fi

    target="$(readlink "$dst")"
    case "$target" in
      "$SCRIPT_DIR/agent/$item")
        log_warn "removing old Pi dotfiles directory link: $dst"
        if ! is_dry_run; then
          rm "$dst"
        fi
        ;;
    esac
  done
}

case "${1:-install}" in
  install)
    ensure_agent_dir
    cleanup_legacy_links

    src="$SCRIPT_DIR/agent/$MANAGED_ITEM"
    dst="$PREFIX/$MANAGED_ITEM"

    if is_dry_run; then
      log_info "DRY: install $src -> $dst"
    else
      if [[ ! -L "$dst" ]] && [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_info "skip (same content): $dst"
        exit 0
      fi
      if [[ -L "$dst" ]] || [[ -e "$dst" ]]; then
        _backup_target "$dst"
      fi
      cp "$src" "$dst"
      log_info "installed: $dst"
    fi
    ;;

  uninstall)
    dst="$PREFIX/$MANAGED_ITEM"
    if [[ -f "$dst" ]] || [[ -L "$dst" ]]; then
      if is_dry_run; then
        log_info "DRY: rm $dst"
      else
        rm "$dst"
        log_info "removed: $dst"
      fi
      _restore_latest_backup "$dst"
    fi
    ;;

  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
