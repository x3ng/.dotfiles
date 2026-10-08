#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"
QML_FILES=(shell.qml Theme.qml AppearanceState.qml Appearance.qml DesktopServices.qml SystemControls.qml DesktopSearch.qml)

user_systemd_available() {
  command -v systemctl >/dev/null 2>&1 &&
    [[ -n "${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/bus" ]]
}

case "${1:-install}" in
  install)
    for file in "${QML_FILES[@]}"; do
      dot_link "$SCRIPT_DIR/$file" "$HOME/.config/quickshell/$file"
    done
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
    for file in "${QML_FILES[@]}"; do
      dot_unlink "$HOME/.config/quickshell/$file"
    done
    if ! is_dry_run && user_systemd_available; then
      systemctl --user daemon-reload || log_warn "could not reload user systemd units"
    fi
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
