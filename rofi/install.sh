#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
  install)
    dot_link "$SCRIPT_DIR/config.rasi" "$HOME/.config/rofi/config.rasi"
    dot_link "$SCRIPT_DIR/theme.rasi" "$HOME/.config/rofi/theme.rasi"
    ;;
  uninstall)
    dot_unlink "$HOME/.config/rofi/theme.rasi"
    dot_unlink "$HOME/.config/rofi/config.rasi"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
