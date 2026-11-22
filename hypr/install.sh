#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

FILES=(
  hyprland.lua
  environment.lua
  compositor.lua
  monitor.lua
  appearance.lua
  binds.lua
  workspaces.lua
  rules.lua
  apps.lua
  startup.lua
)

# Retire only symlinks owned by this package; preserve user-created files.
remove_legacy_links() {
  local name target
  for name in settings.lua hyprlock.conf hyprpaper.conf hypridle.conf; do
    target="$CONFIG_DIR/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$SCRIPT_DIR/$name" ]]; then
      dot_unlink "$target"
    fi
  done
}

case "${1:-install}" in
  install)
    remove_legacy_links
    for f in "${FILES[@]}"; do
      dot_link "$SCRIPT_DIR/$f" "$CONFIG_DIR/$f"
    done
    ;;
  uninstall)
    remove_legacy_links
    for f in "${FILES[@]}"; do
      target="$CONFIG_DIR/$f"
      if [[ -L "$target" && "$(readlink "$target")" == "$SCRIPT_DIR/$f" ]]; then
        dot_unlink "$target"
      else
        log_info "skip (not owned by this package): $target"
      fi
    done
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
