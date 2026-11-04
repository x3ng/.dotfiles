#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"
MODULE_FILES=(shell.qml Theme.qml AppearanceState.qml Appearance.qml DesktopServices.qml IdlePolicy.qml WallpaperState.qml WallpaperImage.qml WallpaperWindows.qml WallpaperPicker.qml wallpaper.json SystemControls.qml DesktopSearch.qml Notifications.qml BatteryAlerts.qml ScreenKeyboard.qml HyprlandControls.qml ShellActions.qml)
GREETER_DIR=/etc/xdg/quickshell/greeter
GREETER_FILES=(shell.qml Theme.qml LoginView.qml SessionCatalog.qml)

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
    dot_link "$SCRIPT_DIR/polkit" "$HOME/.config/quickshell/polkit"
    dot_link "$SCRIPT_DIR/quickshell-polkit.service" "$HOME/.config/systemd/user/quickshell-polkit.service"
    dot_link "$SCRIPT_DIR/lock" "$HOME/.config/quickshell/lock"
    dot_link "$SCRIPT_DIR/qs-lock" "$HOME/.local/bin/qs-lock"
    dot_link "$SCRIPT_DIR/quickshell-lock.service" "$HOME/.config/systemd/user/quickshell-lock.service"
    dot_link "$SCRIPT_DIR/quickshell.service" "$HOME/.config/systemd/user/quickshell.service"
    if ! is_dry_run && user_systemd_available; then
      systemctl --user daemon-reload || log_warn "could not reload user systemd units"
    fi
    ;;
  uninstall)
    # Preflight all active agents before stopping or unlinking any component.
    if ! is_dry_run && user_systemd_available; then
      if systemctl --user is-active --quiet quickshell-lock.service; then
        lock_state=$(timeout 2s quickshell ipc --path "$HOME/.config/quickshell/lock" call locker status) || {
          echo "Cannot confirm lock state; refusing uninstall" >&2; exit 1;
        }
        if [[ "$lock_state" != '{"locked":false,"secure":false}' ]]; then
          echo "Unlock before uninstalling the shell" >&2; exit 1
        fi
      fi
      if systemctl --user is-active --quiet quickshell-polkit.service; then
        polkit_state=$(timeout 2s quickshell ipc --path "$HOME/.config/quickshell/polkit" call polkit status) || {
          echo "Cannot confirm authentication state; refusing uninstall" >&2; exit 1;
        }
        if [[ "$polkit_state" != *'"active":false}' ]]; then
          echo "Finish authentication before uninstalling the shell" >&2; exit 1
        fi
      fi
    fi
    if owned_link "$SCRIPT_DIR/quickshell-polkit.service" "$HOME/.config/systemd/user/quickshell-polkit.service" &&
       ! is_dry_run && user_systemd_available; then
      systemctl --user stop quickshell-polkit.service
    fi
    unlink_owned "$SCRIPT_DIR/quickshell-polkit.service" "$HOME/.config/systemd/user/quickshell-polkit.service"
    unlink_owned "$SCRIPT_DIR/polkit" "$HOME/.config/quickshell/polkit"
    if owned_link "$SCRIPT_DIR/quickshell-lock.service" "$HOME/.config/systemd/user/quickshell-lock.service" &&
       ! is_dry_run && user_systemd_available; then
      systemctl --user stop quickshell-lock.service
    fi
    unlink_owned "$SCRIPT_DIR/quickshell-lock.service" "$HOME/.config/systemd/user/quickshell-lock.service"
    if owned_link "$SCRIPT_DIR/quickshell.service" "$HOME/.config/systemd/user/quickshell.service" &&
       ! is_dry_run && user_systemd_available; then
      systemctl --user stop quickshell.service
    fi
    unlink_owned "$SCRIPT_DIR/quickshell.service" "$HOME/.config/systemd/user/quickshell.service"
    unlink_owned "$SCRIPT_DIR/qs-lock" "$HOME/.local/bin/qs-lock"
    unlink_owned "$SCRIPT_DIR/lock" "$HOME/.config/quickshell/lock"
    unlink_owned "$SCRIPT_DIR/components" "$HOME/.config/quickshell/components"
    for file in "${MODULE_FILES[@]}"; do
      unlink_owned "$SCRIPT_DIR/$file" "$HOME/.config/quickshell/$file"
    done
    if ! is_dry_run && user_systemd_available; then
      systemctl --user daemon-reload || log_warn "could not reload user systemd units"
    fi
    ;;
  install-greeter)
    if is_dry_run; then
      log_info "DRY: install greeter QML to $GREETER_DIR"
    else
      as_root install -d -m 0755 "$GREETER_DIR"
      for file in "${GREETER_FILES[@]}"; do
        as_root install -m 0644 "$SCRIPT_DIR/greeter/$file" "$GREETER_DIR/$file"
      done
    fi
    ;;
  uninstall-greeter)
    if is_dry_run; then
      log_info "DRY: remove greeter QML from $GREETER_DIR"
    else
      for file in "${GREETER_FILES[@]}"; do
        as_root rm -f "$GREETER_DIR/$file"
      done
      as_root rmdir "$GREETER_DIR" 2>/dev/null || :
    fi
    ;;
  *)
    echo "usage: $0 {install|uninstall|install-greeter|uninstall-greeter}" >&2; exit 1
    ;;
esac
