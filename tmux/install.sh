#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
  install)
    if [[ -n "${TMUX_PREFIX:-}" ]]; then
      generated="$HOME/.local/state/dotfiles/tmux.conf"
      if is_dry_run; then
        log_info "DRY: generate $generated with TMUX_PREFIX=$TMUX_PREFIX"
      else
        mkdir -p "$(dirname "$generated")"
        sed "s/C-space/$TMUX_PREFIX/g" "$SCRIPT_DIR/tmux.conf" > "$generated"
      fi
      dot_link "$generated" "$HOME/.config/tmux/tmux.conf"
    else
      dot_link "$SCRIPT_DIR/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    fi
    ;;
  uninstall)
    dot_unlink "$HOME/.config/tmux/tmux.conf"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2
    echo "  TMUX_PREFIX=C-a  use alternate prefix (default: C-space)" >&2
    exit 1
    ;;
esac
