# Quickshell desktop panel

`Super+R` toggles a panel on the focused monitor. It reserves no screen space;
there is no bar. Opening it shows battery status, audio/display controls, media
and tray entries. Typing searches desktop applications and open windows;
clearing the search restores status. The footer keeps the date, time, battery,
volume, brightness and appearance summary visible in both views.

- `Ctrl+N/P` or `Ctrl+J/K`: next/previous result.
- `Ctrl+F/B` or `Ctrl+L/H`: move the search cursor.
- Enter: launch an application or activate a window, then close.
- Esc, Super+R again, or click outside: close.
- Sliders: drag/click or use the wheel. Adjustments keep the panel open.
- Tray: left click activates; right click opens a themed menu.

There are no keyboard modes or pages. Window icons use their appId to resolve
DesktopEntries; unmatched entries receive a generic marker. Volume/brightness
changes also produce a brief independent OSD, including when the panel is closed.

## Structure

| File | Responsibility |
| --- | --- |
| `shell.qml` | Composition and launcher IPC |
| `Theme.qml` | Colours, fonts and shared radii |
| `AppearanceState.qml` | Darkman socket subscription, controls and reconnect |
| `Appearance.qml` | Apply Hyprland colours through `hyprctl eval` |
| `DesktopServices.qml` | PipeWire, UPower, MPRIS and brightness controls |
| `DesktopSearch.qml` | Search, desktop-entry/icon lookup and native activation |
| `components/LauncherPanel.qml` | Panel lifetime, keyboard input and search results |
| `components/StatusPage.qml` | Battery and status control layout |
| `components/MediaCard.qml` | Media artwork, playback and timeline |
| `components/FilledSlider.qml`, `ChoiceButton.qml` | Shared controls |
| `components/TrayMenuPopup.qml` | Themed DBusMenu entries and submenus |
| `components/OsdOverlay.qml` | Independent volume/brightness feedback |

Brightness reads use brightnessctl's native machine-readable output; kernel
backlight events trigger updates through udevadm. No custom watcher daemon or
application index is maintained. Theme colours are semantic; the outer panel is
85% opaque and internal cards are opaque. The launcher namespace is
`quickshell-launcher`; it does not apply fullscreen background blur. The UI requires Quickshell's desktop-entry,
Wayland toplevel, layer-shell and Hyprland monitor APIs.

## Deployment

```sh
./hypr/install.sh install
./quickshell/install.sh install
systemctl --user restart quickshell.service
hyprctl reload
```

The installer links every root QML module and the components directory, and
links the user service. Hyprland starts the service from `hypr/startup.lua`;
systemd restarts it on failure and stops it with the graphical session.

```sh
quickshell ipc call launcher toggle
quickshell ipc call launcher close
systemctl --user status quickshell.service
quickshell log --tail 50
```

## Appearance ownership

Darkman is the only owner of the light/dark mode and sunrise/sunset schedule.
The separate Nix configuration (`software/hyprland.nix`) configures its native
service, GeoClue automatic location and Settings portal. Automatic scheduling
requires a successfully resolved location. Manual selection lasts until the next
automatic transition; there is no permanent override or separate AUTO policy.

`AppearanceState.qml` uses darkman's `$XDG_RUNTIME_DIR/darkman/control.sock`:
`watch` receives mode updates, while a separate connection sends `set dark` or
`set light`. Connections recover after daemon restart. `Appearance.qml` applies
Hyprland's palette from `hypr/appearance.lua`; Hyprland also reads darkman's own
`$XDG_CACHE_HOME/darkman/mode.txt` cache at startup/reload, defaulting to dark if
no cache exists. These require a darkman version with the native socket/cache
interfaces and a Hyprland version with Lua configuration and `hyprctl eval`.
`hyprctl` must be on Quickshell's PATH. Recheck these interfaces on upgrades.

Applications receive the preference through darkman's Settings portal. This
integration never rewrites GTK/Qt themes, icons, fonts, cursors or qt6ct/nwg-look
configuration. Applications must follow the preference themselves; fixed
palettes and legacy applications are not forced to switch. While Quickshell is
stopped, the Portal remains available, but live compositor palette updates wait
for reconnection or a Hyprland reload.

The footer displays OFFLINE when darkman sockets are disconnected, UNSET when
no mode is known, or ERROR when the compositor update failed. Check logs:

```sh
darkman get
darkman set dark
darkman set light
darkman toggle
journalctl --user -u darkman.service -b
```
