#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
  install)
    dot_link "$SCRIPT_DIR/yazi.toml" "$HOME/.config/yazi/yazi.toml"
    dot_link "$SCRIPT_DIR/keymap.toml" "$HOME/.config/yazi/keymap.toml"
    ;;
  uninstall)
    dot_unlink "$HOME/.config/yazi/yazi.toml"
    dot_unlink "$HOME/.config/yazi/keymap.toml"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
