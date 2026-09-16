#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
install)
  dot_link "$SCRIPT_DIR/foot.ini" "$HOME/.config/foot/foot.ini"
  ;;
uninstall)
  dot_unlink "$HOME/.config/foot/foot.ini"
  ;;
*)
  echo "usage: $0 {install|uninstall}" >&2
  exit 1
  ;;
esac
