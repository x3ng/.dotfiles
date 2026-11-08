#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
install)
  dot_link "$SCRIPT_DIR/tmux.conf" "$HOME/.config/tmux/tmux.conf"
  dot_link "$SCRIPT_DIR/transpose.py" "$HOME/.config/tmux/transpose.py"
  ;;
uninstall)
  dot_unlink "$HOME/.config/tmux/tmux.conf"
  dot_unlink "$HOME/.config/tmux/transpose.py"
  ;;
*)
  echo "usage: $0 {install|uninstall}" >&2
  exit 1
  ;;
esac
