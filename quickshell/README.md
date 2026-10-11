# Quickshell desktop panel

`Super+R` toggles a panel on the focused monitor. It reserves no screen space;
there is no bar. Each page sizes to its content, with one height ceiling:
`Theme.maximumPanelHeight` (700px by default), also limited by available screen
space. Width is capped at 680px. Height changes animate while the top edge
stays in place, and excess content scrolls without a scrollbar. Status and
search keep the search field and compact footer; device and notification
pages replace them with their own return/title header. Opening it shows a quick-settings style grid: Wi-Fi and
Bluetooth tiles, volume and brightness sliders on the same center split, then
one toggle button per function (mic/output mute, audio devices, dark mode,
keep awake, power profiles) in an evenly spaced grid whose center seam lines
up with the tiles and sliders above, plus media
and tray entries. Used workspaces appear at the top of the status page,
first in the scrolling overview, with a number and application icons; clicking a
workspace switches to it without closing the panel. Search and detail pages
focus on their own content and do not show workspace navigation.
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
  Applications, including the terminal wrapper, run in independent systemd user
  scopes in `app.slice`; restarting `quickshell.service` does not terminate them.
  The scope inherits the launcher's environment, and systemd argument expansion
  is disabled to preserve literal `$` characters. The service retains its default
  `KillMode=control-group` to clean up shell-owned helpers. Applications already
  running in the old service cgroup must be exited and relaunched to move scopes.
- `Ctrl+1`–`Ctrl+9`, `Ctrl+0`: directly open search results 1–10. The list
  uses compact single-line rows to fit the first ten results at normal screen sizes
  and displays these shortcuts; they do nothing on the status view or for missing results.
- Esc: return from search or details to status; on status, close the panel.
  Super+R again, Ctrl+G, or clicking outside closes from any page.
- Sliders: drag/click or use the wheel. Adjustments keep the panel open.
- Status page: workspace context appears first in its scrolling content. Below it, connectivity,
  volume/brightness and quick toggles come first,
  followed by the media card when a player is available, then the notification
  preview. Notifications show two recent entries with up to two body lines,
  a pending count, a separate Clear button and a history footer. The page
  scrolls when needed without showing a scrollbar.
  Opening or returning to status resets its scroll position for a fresh overview.
- Keep awake: toggle to inhibit automatic idle locking and screen power-off
  through Hypridle. The highlighted button stays active when the panel closes;
  toggle it off to restore idle timeouts. Quickshell exit/reload releases it.
  Uses the existing `systemd-inhibit` command; manual locking still works.
- Tray: left click activates; right click opens a themed menu.
- Notifications: quickshell replaces mako as the Freedesktop notification
  daemon. Banners appear top-center on the focused monitor, at up to 400 logical
  pixels wide with margins on narrower screens. Up to four cards are visible;
  overflow evicts the oldest unhovered card. Tall stacks scroll within 75% of
  the screen height. Normal banners honor the app's timeout, or five seconds
  by default; critical notifications and a zero timeout stay until closed.
  Hovering pauses the countdown and leaving resumes the remaining time.
  Application icons and attached images are separate, with icon fallbacks for
  missing icons. Titles and bodies wrap, including long URLs and Chinese text.
  "Show more" expands truncated text or an image; long expanded bodies scroll
  inside the card. Text is explicitly plain text, matching the advertised
  capabilities. Action buttons wrap onto additional rows. The default action
  is invoked by clicking the card's content when it does not need expanding;
  it is not duplicated as a labeled button. Resident actions leave the card
  open, and the sender can close it. Use the close button to dismiss a banner.
  Pending entries and saved history remain after a banner closes or expires.
  The status page previews the newest two pending entries with up to two body
  lines each; clicking a preview opens history, and its close button removes
  only that pending entry.
  "Clear" clears pending entries only. History uses the same card layout with
  expandable content, per-entry close buttons and "Clear all history".
  Pending is capped at twenty entries and history at fifty; both are saved in
  quickshell's per-shell cache directory and survive restarts. Notifications
  updated with `replaces_id` update the existing live card and saved entry.
  Transient notifications are also recorded by default, including fcitx5's
  Wayland diagnostic tips; set `recordTransient` to `false` in
  `Notifications.qml` to keep them toast-only. File-backed attached images can
  be shown in history; in-memory `image://qsimage/` attachments are shown live
  but omitted from disk because their URLs expire with the notification.
- Wi-Fi and Bluetooth: click the icon to toggle the radio, or the card text/arrow
  to open a detail view inside the same panel. Audio devices opens the same
  view, with output/microphone tabs. Details are independent content-sized
  pages, with a return/title header instead of the main search field and footer.
  Their lists and controls scroll together once the shared height ceiling is
  reached; the return header stays visible.
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

Each workspace also displays a compact marker for its actual Hyprland tiled
layout (D = dwindle, M = master, S = scrolling, O = monocle) beside its number,
in both the panel and workspace OSD. Number and marker form a single 14px
semibold label, such as `3·S`, with width measured from its text and compact
spacing between application icons. Hovering a workspace in the panel shows
the full layout name. The workspace OSD grows with its content up to the screen
width minus 64 pixels, wrapping only when that available width is exhausted.
Changing the focused workspace's layout shows the same OSD. Layout state is read
from `hyprctl -j workspaces`, shared by both views, and refreshed on workspace,
reload and custom layout events. A three-second reconciliation catches layout
changes made by external commands; initial discovery stays silent.

Hyprland keeps the existing general bindings and switches only the current
workspace's layout with `Super+Alt+D/M/S/O` for dwindle, master, scrolling,
and monocle respectively. Number bindings are reserved for workspaces.
When a special workspace is open, layout selection applies to it instead of
the regular workspace behind it.

Additional bindings:

| Binding | Dwindle | Master | Scrolling | Monocle |
| --- | --- | --- | --- | --- |
| `Super+H/K`, `Super+J/L` | Directional focus | Directional focus | H/L focus columns with wraparound; J/K directional focus | Previous / next tiled window |
| `Super+Ctrl+H/L` | Resize width by −/+10 px | Same | Resize column by −/+5% of usable width and refit view | General resize dispatcher |
| `Super+Ctrl+Shift+H/L` | — | — | Swap whole column left/right, stopping at edges | — |
| `Super+[` / `Super+]` | Previous / next workspace window | Same | Same | Same |
| `Super+T` | Toggle split | Rotate master orientation | Center current column | — |
| `Super+Shift+Return` | — | Swap with master, focus master | Extract focused window into its own column | — |
| `Super+Shift+]` | — | — | Pull first window of next column into current column | — |
| `Super+Shift+[` | — | — | Expel last window of current column into its own column | — |

Layout-specific structural operations ignore floating windows and unsupported
layouts. Floating-window directional focus retains its usual behavior.
`Super+Ctrl+H/L` retains pixel resizing for floating windows. `Super+Ctrl+K/J`
retains the general resize dispatcher with +10/−10 px height changes. All four
resize bindings repeat while held.
`Super+Tab` / `Super+Shift+Tab` still switch tabs within a window group.

## Structure

| File | Responsibility |
| --- | --- |
| `shell.qml` | Composition and launcher IPC |
| `Theme.qml` | Colours, typography scale, spacing scale and shared radii |
| `AppearanceState.qml` | Darkman socket subscription, controls and reconnect |
| `Appearance.qml` | Publish application colour preference and apply Hyprland colours |
| `DesktopServices.qml` | Audio devices, UPower, MPRIS, brightness and keep-awake controls |
| `SystemControls.qml` | Native network, Bluetooth and power objects, signals and actions |
| `DesktopSearch.qml` | Search, desktop-entry/icon lookup, window activation and application scopes |
| `Notifications.qml` | Notification daemon: tracking, popup queue and history |
| `components/LauncherPanel.qml` | Content-sized pages, shared height ceiling, navigation and search |
| `components/WorkspaceLayoutState.qml` | Shared per-workspace layout state and change signals |
| `components/NotificationBanner.qml` | Screen-aware top-center notification stack |
| `components/NotificationCard.qml` | Shared popup, preview and history card layout |
| `components/NotificationUtils.js` | Icon URL normalization and persistent-image filtering |
| `components/StatusPage.qml` | Scrollable workspace overview, controls, media and notification preview |
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

## Portability and dependencies

This is a reusable **Hyprland/Linux** shell configuration, not a compositor-
independent desktop shell. No username, monitor connector or literal Nix store
path is embedded in QML. State uses XDG directories; layout sizes, palettes and
limits are personal defaults that can be adjusted in QML.

- Require Quickshell 0.3.1 APIs and their Qt modules, Hyprland with the Lua
  configuration/`hyprctl eval` API, and a modern systemd user session supporting
  `systemd-run --expand-environment=no`. Hyprland's appearance Lua module must
  be deployed alongside the shell. Another compositor requires an adapter.
- The dotfiles service searches standard binary directories and Nix profiles;
  it does not pin Quickshell to a Nix executable path. `ExecSearchPath` requires
  systemd 250 or later. Optional Nix search directories need not exist on other
  distributions. Commands launched by the shell must be available in its PATH.
- Application appearance requires `gsettings`, the desktop-interface schema,
  a persistent dconf backend and GTK Settings portal selected for this session.
  Nix packages the tool with this environment; other distributions normally
  install it in standard data directories. Missing synchronization dependencies
  are errors, not a substitute for application appearance support.
- Audio uses PipeWire, networking NetworkManager, Bluetooth BlueZ, battery
  UPower and power profiles power-profiles-daemon. Hardware-dependent controls
  can be absent. The current power-profile adapter does not reliably distinguish
  a missing daemon; provision it when using those buttons.
- Backlight controls use `brightnessctl` (with user permissions) and `udevadm`.
  Keep-awake uses `systemd-inhibit` and `cat`; application launches use
  `systemd-run`. Media uses any MPRIS player; tray applications must implement
  StatusNotifierItem/DBusMenu.
- `DesktopSearch.terminalCommand` is the shared terminal argv for terminal
  applications and the `nmtui` network-management entry. Default is kitty;
  change it for another terminal (including its execute argument). Install
  `nmtui` to use that entry. Desktop-services instantiated outside `shell.qml`
  can supply their own terminal argv.
- This shell owns `org.freedesktop.Notifications`; do not run a second
  notification daemon alongside it.

The Nix module also contains personal login/lid/power policy, greeter and theme
asset choices. Review those before reusing it; they are host policy, not shell
requirements. GNOME/KDE Settings backends would require a different write adapter.

## Appearance ownership

Quickshell owns manual light/dark selection and saves it in
`$XDG_STATE_HOME/quickshell/appearance-mode` (default `~/.local/state`).
Hyprland reads the same file on startup/config reload. There is currently no
automatic sunrise/sunset schedule.

The shell directly calls `gsettings set org.gnome.desktop.interface color-scheme`
and updates Hyprland's palette. GTK's Settings portal exposes the standard
`org.freedesktop.appearance/color-scheme` preference to applications. Application
styles and fixed GTK/Qt themes are not rewritten.

Nix installs a wrapped **gsettings tool**, providing its desktop schema and dconf
module paths. QML contains no Nix schema paths, directory discovery or shell
command strings. Quickshell starts directly from the dotfiles-owned service;
there is no Nix-defined Quickshell service or additional startup script.
Other distributions can provide the same standard command through their packages.

Apply the Nix configuration before relying on application synchronization.
The footer reports persistence/synchronization errors. Check:

```sh
quickshell ipc call appearance status
quickshell ipc call appearance setMode dark
gsettings get org.gnome.desktop.interface color-scheme
journalctl --user -u quickshell.service -b
```

### Notification implementation references

The layout and lifecycle were reviewed against
[Noctalia's toast implementation](https://github.com/noctalia-dev/noctalia/blob/b2e3ffb/src/shell/notification/notification_toast.cpp)
and [DMS's shared notification card](https://github.com/AvengeMedia/DankMaterialShell/blob/6d331b8/quickshell/Modules/Notifications/NotificationCard.qml)
and [notification service](https://github.com/AvengeMedia/DankMaterialShell/blob/6d331b8/quickshell/Services/NotificationService.qml).
The current Noctalia implementation is native C++; this config follows its
layout patterns rather than importing its code. The relevant practices here
are content-sized cards, wrapped actions, a separate close control, expandable
text, separate app icons and attachments, hover-aware expiry, and updating
existing notifications. Remote markup, inline replies, app grouping and an
image-file cache are not implemented or advertised by this shell.

### Widget and detail-menu review

Reviewed against [Noctalia control-center tabs](https://github.com/noctalia-dev/noctalia/tree/b2e3ffb/src/shell/control_center/tabs)
and [DMS control-center widgets](https://github.com/AvengeMedia/DankMaterialShell/tree/6d331b8/quickshell/Modules/ControlCenter/Widgets).
Keep this a personal QML configuration; introduce shared infrastructure only
when repeated behavior actually needs it.

| Area | Current behavior and useful remaining gaps |
| --- | --- |
| Wi-Fi | Nearby saved networks, connection feedback and external network-manager entry. New networks, passwords, enterprise authentication, network details and disconnect remain outside this menu. |
| Bluetooth | Paired devices, connect/disconnect, transition labels and reported battery percentage. Discovery, pairing/passkey agent, trust/remove and codec selection are not implemented. |
| Audio | Output/input selection, volume and mute. Per-application volume and Bluetooth profile selection are possible later additions. |
| Media | Playing player preferred, transport buttons and read-only timeline. Explicit player selection and seeking are useful next additions; shuffle/repeat should respect player capabilities. |
| Power | Profiles and keep-awake toggle. Profile availability/degradation feedback and timed inhibition need further work. |
| Tray | Native DBusMenu submenus, disabled entries, checkboxes/radio items and scrolling. Escape returns from a submenu before closing. Arrow-key navigation remains a gap. |

Wi-Fi and Bluetooth have separate busy states; audio and power controls are not
blocked by unrelated connection work. Bluetooth device actions are guarded per
device. Device lists show transitions rather than presenting an idle clickable
row during connection. Noctalia's network sorting avoids raw signal-strength
updates moving click targets; preserve stable sorting here. DMS's pairing flow
uses a BlueZ agent in its backend: a discovery/pair button alone cannot safely
replace the missing passkey/confirmation flow.

For this config, prioritize a player chooser/seek interaction and a reliable
external Bluetooth-manager entry before adding a full authentication stack.
Do not expose unsupported controls just to match upstream feature counts.
