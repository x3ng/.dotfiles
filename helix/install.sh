#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
  install)
    dot_link "$SCRIPT_DIR/config.toml" "$HOME/.config/helix/config.toml"
    dot_link "$SCRIPT_DIR/languages.toml" "$HOME/.config/helix/languages.toml"
    ;;
  uninstall)
    dot_unlink "$HOME/.config/helix/config.toml"
    dot_unlink "$HOME/.config/helix/languages.toml"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
