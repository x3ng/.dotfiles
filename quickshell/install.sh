#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"
MODULE_FILES=(shell.qml Theme.qml AppearanceState.qml Appearance.qml DesktopServices.qml SystemControls.qml DesktopSearch.qml Notifications.qml BatteryAlerts.qml ScreenKeyboard.qml HyprlandControls.qml ShellActions.qml)

user_systemd_available() {
  command -v systemctl >/dev/null 2>&1 &&
    [[ -n "${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/bus" ]]
}

owned_link() {
  [[ -L "$2" && "$(readlink "$2")" == "$1" ]]
}

unlink_owned() {
  if owned_link "$1" "$2"; then
    dot_unlink "$2"
  else
    log_info "skip (not owned by this package): $2"
  fi
}

case "${1:-install}" in
  install)
    # Retire only our obsolete module link; leave user files and saved state intact.
    if [[ -L "$HOME/.config/quickshell/PanelState.qml" ]] && \
       [[ "$(readlink "$HOME/.config/quickshell/PanelState.qml")" == "$SCRIPT_DIR/PanelState.qml" ]]; then
      dot_unlink "$HOME/.config/quickshell/PanelState.qml"
    fi
    for file in "${MODULE_FILES[@]}"; do
      dot_link "$SCRIPT_DIR/$file" "$HOME/.config/quickshell/$file"
    done
    dot_link "$SCRIPT_DIR/components" "$HOME/.config/quickshell/components"
    dot_link "$SCRIPT_DIR/quickshell.service" "$HOME/.config/systemd/user/quickshell.service"
    if ! is_dry_run && user_systemd_available; then
      systemctl --user daemon-reload || log_warn "could not reload user systemd units"
    fi
    ;;
  uninstall)
    if owned_link "$SCRIPT_DIR/quickshell.service" "$HOME/.config/systemd/user/quickshell.service" &&
       ! is_dry_run && user_systemd_available; then
      systemctl --user stop quickshell.service || log_warn "could not stop Quickshell service"
    fi
    unlink_owned "$SCRIPT_DIR/quickshell.service" "$HOME/.config/systemd/user/quickshell.service"
    unlink_owned "$SCRIPT_DIR/components" "$HOME/.config/quickshell/components"
    for file in "${MODULE_FILES[@]}"; do
      unlink_owned "$SCRIPT_DIR/$file" "$HOME/.config/quickshell/$file"
    done
    if ! is_dry_run && user_systemd_available; then
      systemctl --user daemon-reload || log_warn "could not reload user systemd units"
    fi
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2; exit 1
    ;;
esac
