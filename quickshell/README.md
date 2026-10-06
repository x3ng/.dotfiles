# Quickshell

`shell.qml` owns shared state, IPC and brightness monitoring. The per-monitor
bar lives in `components/BarWindow.qml`; its workspace strip and system tray
drawer are separate components. `Theme.qml` defines the palette and remembers
the dark/light choice.

`./quickshell/install.sh install` links the config and the user-level
`quickshell.service`. Hyprland starts that service from `hypr/startup.lua`.
Systemd restarts Quickshell after an unexpected exit and stops it with the
graphical session. The unit is linked, not enabled for non-Hyprland logins.

Useful checks:

```sh
systemctl --user status quickshell.service
systemctl --user restart quickshell.service
quickshell log --tail 50
```

Appearance is stored under `$XDG_STATE_HOME/quickshell/by-shell/<shell-id>/appearance.json`
(`~/.local/state` is used when `XDG_STATE_HOME` is unset). The shell ID is
derived from the Quickshell config, so it remains stable across service restarts.

The bar toggle slides its contents through a shrinking layer surface, then
unmaps the window. Its 479ms duration and Bezier curve match the `windows`
animation in `hypr/compositor.lua`; keep these settings aligned when tuning
the motion. Reserved space changes once per toggle so Hyprland can animate
window reflow without receiving a new target every frame. The
`quickshell:bar` layer has compositor animations disabled in `hypr/apps.lua`
to avoid replaying the bar after its QML animation ends.
