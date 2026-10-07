#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

user_systemd_available() {
  command -v systemctl >/dev/null 2>&1 &&
    [[ -n "${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/bus" ]]
}

case "${1:-install}" in
  install)
    dot_link "$SCRIPT_DIR/shell.qml" "$HOME/.config/quickshell/shell.qml"
    dot_link "$SCRIPT_DIR/Theme.qml" "$HOME/.config/quickshell/Theme.qml"
    dot_link "$SCRIPT_DIR/Appearance.qml" "$HOME/.config/quickshell/Appearance.qml"
    dot_link "$SCRIPT_DIR/components" "$HOME/.config/quickshell/components"
    dot_link "$SCRIPT_DIR/quickshell.service" "$HOME/.config/systemd/user/quickshell.service"
    if ! is_dry_run && user_systemd_available; then
      systemctl --user daemon-reload || log_warn "could not reload user systemd units"
    fi
    ;;
  uninstall)
    if ! is_dry_run && user_systemd_available; then
      systemctl --user stop quickshell.service || log_warn "could not stop Quickshell service"
    fi
    dot_unlink "$HOME/.config/systemd/user/quickshell.service"
    dot_unlink "$HOME/.config/quickshell/components"
    dot_unlink "$HOME/.config/quickshell/Theme.qml"
    dot_unlink "$HOME/.config/quickshell/Appearance.qml"
    dot_unlink "$HOME/.config/quickshell/shell.qml"
    if ! is_dry_run && user_systemd_available; then
      systemctl --user daemon-reload || log_warn "could not reload user systemd units"
    fi
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
