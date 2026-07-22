#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

PREFIX="${PI_AGENT_HOME:-$HOME/.pi/agent}"

# Pi declarative config managed via symlinks for real-time sync.
# settings.json is the root: packages, theme, thinking level.
# extension configs under extensions/*/config.json are optional policy files.
# Both are symlinked so edits in dotfiles take effect immediately.
# Pi may write runtime keys (e.g. lastChangelogVersion) to settings.json;
# those show as dirty in git — commit them as part of normal maintenance.

LEGACY_LINKS=(
  AGENTS.md agents skills prompts subagents.json pi-goal.json extensions themes
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

# Symlink a single file from dotfiles to Pi agent, creating parent dirs as needed.
# $1 = relative path under pi/agent/ (e.g. "settings.json", "extensions/pi-permission-system/config.json")
link_managed_file() {
  local rel="$1"
  local src="$SCRIPT_DIR/agent/$rel"
  local dst="$PREFIX/$rel"
  local dst_dir
  dst_dir="$(dirname "$dst")"

  if is_dry_run; then
    log_info "DRY: mkdir -p $dst_dir"
    log_info "DRY: ln -sf $src -> $dst"
    return
  fi

  mkdir -p "$dst_dir"

  if [[ -L "$dst" ]]; then
    local current_target
    current_target="$(readlink "$dst")"
    if [[ "$current_target" == "$src" ]]; then
      log_info "skip (already linked): $dst"
      return
    fi
  fi

  if [[ -f "$dst" ]] && [[ ! -L "$dst" ]]; then
    _backup_target "$dst"
  fi

  ln -sf "$src" "$dst"
  log_info "linked: $dst -> $src"
}

# Remove a managed symlink and restore any backup.
unlink_managed_file() {
  local rel="$1"
  local dst="$PREFIX/$rel"

  if [[ -L "$dst" ]]; then
    if is_dry_run; then
      log_info "DRY: rm $dst"
    else
      rm "$dst"
      log_info "removed: $dst"
    fi
    _restore_latest_backup "$dst"
  fi
}

install_all() {
  ensure_agent_dir
  cleanup_legacy_links

  # Core settings
  link_managed_file "settings.json"

  # Extension configs
  local ext_config
  for ext_config in "$SCRIPT_DIR/agent/extensions"/*/config.json; do
    [[ -f "$ext_config" ]] || continue
    local rel="${ext_config#$SCRIPT_DIR/agent/}"
    link_managed_file "$rel"
  done
}

uninstall_all() {
  local ext_config
  for ext_config in "$SCRIPT_DIR/agent/extensions"/*/config.json; do
    [[ -f "$ext_config" ]] || continue
    local rel="${ext_config#$SCRIPT_DIR/agent/}"
    unlink_managed_file "$rel"
  done

  unlink_managed_file "settings.json"
}

case "${1:-install}" in
  install)   install_all ;;
  uninstall) uninstall_all ;;
  *)         echo "usage: $0 {install|uninstall}" >&2; exit 1 ;;
esac
