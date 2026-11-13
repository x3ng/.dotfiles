#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

# Link individual settings files; history, images and logs remain local.
FILES=(config.json custom_theme.json)
case "${1:-install}" in
  install)
    for f in "${FILES[@]}"; do
      dot_link "$SCRIPT_DIR/$f" "$HOME/.config/clipse/$f"
    done
    ;;
  uninstall)
    for f in "${FILES[@]}"; do
      target="$HOME/.config/clipse/$f"
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
