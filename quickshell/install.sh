#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
  install)
    dot_link "$SCRIPT_DIR/shell.qml" "$HOME/.config/quickshell/shell.qml"
    dot_link "$SCRIPT_DIR/Theme.qml" "$HOME/.config/quickshell/Theme.qml"
    dot_link "$SCRIPT_DIR/components" "$HOME/.config/quickshell/components"
    ;;
  uninstall)
    dot_unlink "$HOME/.config/quickshell/components"
    dot_unlink "$HOME/.config/quickshell/Theme.qml"
    dot_unlink "$HOME/.config/quickshell/shell.qml"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
