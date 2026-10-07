# Quickshell

`shell.qml` owns shared state, IPC and brightness monitoring. The per-monitor
bar lives in `components/BarWindow.qml`; its workspace strip and system tray
drawer are separate components. `Theme.qml` defines the palette and follows darkman through its Unix socket.
Quickshell does not own a separate appearance preference.

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

Darkman is the only owner of the light/dark mode and sunrise/sunset schedule.
NixOS configures its native service, GeoClue automatic location and the Settings
portal in the separate Nix configuration (`software/hyprland.nix`). No coordinates, custom scheduler,
policy file or separate appearance CLI are needed. Automatic transitions require
GeoClue to successfully resolve a location; check the service logs if it cannot.

Deploy the Quickshell config and Hyprland palette module:

```sh
./hypr/install.sh install
./quickshell/install.sh install
```

`Theme.qml` subscribes to darkman's native Unix socket with `watch`, and sends
`set dark` / `set light` on a separate socket. It reconnects after a daemon
restart and receives the current mode immediately. Manual selection lasts until
the next automatic transition; there is no permanent override or separate AUTO
policy. OFFLINE means disconnected, UNSET means no known mode, and ERROR means
the compositor adapter failed (see Quickshell logs).

Darkman's Settings portal publishes the global light/dark preference for
applications to follow. GTK themes, qt6ct palettes, fonts, icons and cursors are
not rewritten, generated or owned by Quickshell. Keep using nwg-look and qt6ct
for those settings. This integration assumes applications follow the preference;
it intentionally does not force legacy applications or fixed palettes to switch.
An icon theme's `FollowsColorScheme` flag is not a promise of portal support.

`Appearance.qml` only calls the native `hyprctl eval` interface to apply the
compositor's palette from `hypr/appearance.lua`. There are no theme hooks, shell
wrappers, dconf writes or application configuration edits on this path. Hyprland
also restores darkman's own cached mode on startup/config reload. While
Quickshell is stopped, applications can still receive the portal preference,
but compositor colours wait until Quickshell reconnects or Hyprland reloads.

Quickshell supplies no built-in sunrise/sunset scheduler or geolocation policy;
this configuration delegates both to darkman/GeoClue.

The integration requires a darkman version with `$XDG_RUNTIME_DIR/darkman/control.sock`
(`watch` and `set` commands), its `$XDG_CACHE_HOME/darkman/mode.txt` cache, and a
Hyprland version supporting Lua configuration and `hyprctl eval`. `hyprctl` must
be available on Quickshell's PATH. With no cached mode, Hyprland starts with the
dark palette until Quickshell receives the current mode. These are upstream
interfaces; recheck them when upgrading either component.

Quickshell's semantic colours live in `Theme.qml`; components use colour roles
rather than mode-specific hex values. Hyprland's border, groupbar and shadow
colours live only in `hypr/appearance.lua`. Light surfaces are nearly opaque to
keep wallpaper colours from undermining text contrast. Selected controls have
separate background/foreground roles from hover states.

```sh
darkman get
darkman set dark
darkman set light
darkman toggle
systemctl --user status darkman.service
journalctl --user -u darkman.service -b
```

The bar toggle slides its contents through a shrinking layer surface, then
unmaps the window. Its 479ms duration and Bezier curve match the `windows`
animation in `hypr/compositor.lua`; keep these settings aligned when tuning
the motion. Reserved space changes once per toggle so Hyprland can animate
window reflow without receiving a new target every frame. The
`quickshell:bar` layer has compositor animations disabled in `hypr/apps.lua`
to avoid replaying the bar after its QML animation ends.
