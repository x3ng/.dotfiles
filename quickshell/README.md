# Quickshell desktop panel

`Super+R` toggles a panel on the focused monitor. It reserves no screen space;
there is no bar. Both status and search fit their content up to a 700px maximum height (or the available
screen height); excess content scrolls. The panel width is capped at 680px and fades
in and out rather than popping. The search field keeps its position
between views. Opening it shows a quick-settings style grid: Wi-Fi and
Bluetooth tiles, volume and brightness sliders on the same center split, then
one toggle button per function (mic/output mute, audio devices, dark mode,
keep awake, power profiles) in an evenly spaced grid whose center seam lines
up with the tiles and sliders above, plus media
and tray entries. Used workspaces appear below the controls with a number and
application icons; clicking a workspace switches to it without closing the panel.
Workspace groups wrap instead of scrolling; the current workspace is included
even when empty. Typing searches desktop applications and open windows; results
are ranked by match quality (prefix, then word start, then substring), and an
open window only ranks highly when its title matches, so the best hit sits on
top and Enter does the expected thing. Clearing the search restores status. The footer keeps the date, time, battery,
volume, brightness and appearance summary visible in both views. Search and
footer share the same 40px strip height; battery details are available on hover
over the footer battery icon.

- `Ctrl+N/P`: next/previous result.
- `Ctrl+A/E`: beginning/end of input; `Ctrl+F/B`: character forward/back.
- `Alt+F/B`: word forward/back; `Alt+D` / `Alt+Backspace`: kill next/previous word.
- `Ctrl+K/U`: kill to end/beginning; `Ctrl+W`: kill selection or previous word.
- `Ctrl+H/D`: backward/forward delete; `Ctrl+Y`: restore the last killed text.
- `Ctrl+G`: close. Vim-style result navigation is not used.
- Enter: launch an application or activate a window, then close.
- Applications declaring `Terminal=true` (such as Yazi) open in kitty automatically.
  `Shift+Enter` forces a selected application to open in the terminal; window results
  still activate the existing window. `DesktopSearch.qml`'s `terminalCommand`
  configures the terminal argv (default `["kitty", "--"]`). Native desktop-entry
  arguments and working directories are preserved without shell string parsing.
- `Ctrl+1`–`Ctrl+9`, `Ctrl+0`: directly open search results 1–10. The list
  uses compact single-line rows to fit the first ten results at normal screen sizes
  and displays these shortcuts; they do nothing on the status view or for missing results.
- Esc, Super+R again, or click outside: close.
- Sliders: drag/click or use the wheel. Adjustments keep the panel open.
- Keep awake: toggle to inhibit automatic idle locking and screen power-off
  through Hypridle. The highlighted button stays active when the panel closes;
  toggle it off to restore idle timeouts. Quickshell exit/reload releases it.
  Uses the existing `systemd-inhibit` command; manual locking still works.
- Tray: left click activates; right click opens a themed menu.
- Notifications: quickshell replaces mako as the Freedesktop notification
  daemon. Pending notifications and saved history are separate lists, as in
  Noctalia and DankMaterialShell. Banners appear top-center (360px wide, 10px
  below the top edge), fade in as they arrive, show up to four at a time with
  older ones evicted, and expire after the app's timeout or five seconds by
  default; critical notifications stay until clicked. Clicking a banner or
  letting it time out only hides the toast - the entry stays pending - and
  action buttons invoke the app's actions and close. The status page always
  shows a notification card: the newest three pending entries, or an empty
  state when there are none, so the panel never reflows. Its "Clear" empties
  the pending list only and never touches history; single rows dismiss
  individually. The card opens the detail page, which lists the saved history
  newest first with a per-row dismiss and "Clear all history". Pending is
  capped at twenty entries and history at fifty; both are written to
  quickshell's per-shell cache directory, so they survive restarts but not a
  change of configuration path. Transient notifications are toast-only and
  never enter either list. Panel height eases between content lengths instead
  of snapping.
- Wi-Fi and Bluetooth: click the icon to toggle the radio, or the card text/arrow
  to open a detail view inside the same panel. Audio devices opens the same
  view, with output/microphone tabs. Details replace the status content and
  search field, retaining the footer and giving lists the full content area.
  The back arrow or Esc returns to status; outside click closes the launcher.
  Power profiles are selected directly in the main panel.
  Wi-Fi offers saved networks nearby and opens the existing `nmtui` in
  kitty for other networks. Bluetooth connects/disconnects paired devices;
  pairing new devices remains outside this panel. Audio selects the default
  output/input through PipeWire. Power mode offers the profiles reported by
  the native PowerProfiles service. Wi-Fi connection failures show inline.
  Network, Bluetooth and power status follow native D-Bus-backed Quickshell
  objects and their change signals; there is no CLI text parsing or status
  polling. Wi-Fi scanning runs only while the panel is open. These controls
  require the existing Quickshell Networking, Bluetooth and UPower modules.

There are no keyboard modes. The media card appears only when a player exists.
Window icons use their appId to resolve
DesktopEntries; unmatched entries draw a generic window/app glyph from
`StatusIcon` (the same line-icon set backs transport, chevron, check and
close controls — no Unicode glyph fallbacks). Volume/brightness
changes also produce a brief independent OSD, including when the panel is closed.
While muted, the OSD keeps the MUTED label and shows the stored volume with a
neutral progress bar; adjusting volume does not unmute it. Switching the focused
workspace shows the workspace numbers and application icons for one second on
the focused monitor, with the current workspace highlighted. This OSD reuses the
panel's workspace layout, wraps within the screen width, and fades in/out with a
slight vertical motion. It does not accept input.
Initial workspace discovery does not show a popup.

## Structure

| File | Responsibility |
| --- | --- |
| `shell.qml` | Composition and launcher IPC |
| `Theme.qml` | Colours, typography scale, spacing scale and shared radii |
| `AppearanceState.qml` | Darkman socket subscription, controls and reconnect |
| `Appearance.qml` | Apply Hyprland colours through `hyprctl eval` |
| `DesktopServices.qml` | Audio devices, UPower, MPRIS, brightness and keep-awake controls |
| `SystemControls.qml` | Native network, Bluetooth and power objects, signals and actions |
| `DesktopSearch.qml` | Search, desktop-entry/icon lookup and native activation |
| `Notifications.qml` | Notification daemon: tracking, popup queue and history |
| `components/LauncherPanel.qml` | Panel lifetime, keyboard input and search results |
| `components/NotificationBanner.qml` | Top-right notification banners |
| `components/StatusPage.qml` | Audio, brightness, appearance, media and workspace layout |
| `components/DesktopControls.qml`, `ControlTile.qml` | Connectivity cards with direct radio toggles |
| `components/ControlDetails.qml`, `DeviceRow.qml` | In-panel network/Bluetooth/audio detail views and device selection |
| `components/EmacsInput.qml` | Readline-style input editing and local kill buffer |
| `components/WorkspaceSummary.qml` | Used workspace numbers and application icons |
| `components/MediaCard.qml` | Media artwork, playback and timeline |
| `components/FilledSlider.qml`, `ChoiceButton.qml` | Shared controls |
| `components/StatusIcon.qml` | Palette-aware status icons without an icon-font dependency |
| `components/PanelFooter.qml` | Date/time, icon-based status summary and tray entries |
| `components/TrayMenuPopup.qml` | Themed DBusMenu entries and submenus |
| `components/OsdOverlay.qml` | Independent volume/brightness/workspace feedback |

Brightness reads use brightnessctl's native machine-readable output; kernel
backlight events trigger updates through udevadm. No custom watcher daemon or
application index is maintained. Theme colours are semantic; every text size and
common spacing maps to a `Theme` token (one-off optical adjustments stay
literal), and the palette is shared with `hypr/appearance.lua` — change both
together. Panels and internal
cards are opaque for readability. The launcher namespace is
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

The footer marks unavailable/error appearance state with `!`, or an unknown
mode with `?`; hovering shows the status. Check logs:

```sh
darkman get
darkman set dark
darkman set light
darkman toggle
journalctl --user -u darkman.service -b
```
