#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

FILES=(
  hyprland.lua
  settings.lua
  binds.lua
  rules.lua
  startup.lua
  hypridle.conf
  hyprlock.conf
)

case "${1:-install}" in
  install)
    for f in "${FILES[@]}"; do
      dot_link "$SCRIPT_DIR/$f" "$HOME/.config/hypr/$f"
    done
    ;;
  uninstall)
    for f in "${FILES[@]}"; do
      dot_unlink "$HOME/.config/hypr/$f"
    done
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
