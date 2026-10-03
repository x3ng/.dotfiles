#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

FILES=(
  hyprland.lua
  environment.lua
  compositor.lua
  binds.lua
  rules.lua
  apps.lua
  startup.lua
  hypridle.conf
  hyprlock.conf
)

remove_legacy_settings() {
  local target="$HOME/.config/hypr/settings.lua"
  if [[ -L "$target" && "$(readlink "$target")" == "$SCRIPT_DIR/settings.lua" ]]; then
    dot_unlink "$target"
  fi
}

case "${1:-install}" in
  install)
    remove_legacy_settings
    for f in "${FILES[@]}"; do
      dot_link "$SCRIPT_DIR/$f" "$HOME/.config/hypr/$f"
    done
    ;;
  uninstall)
    remove_legacy_settings
    for f in "${FILES[@]}"; do
      dot_unlink "$HOME/.config/hypr/$f"
    done
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
