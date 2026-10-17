# Quickshell desktop panel

For module ownership and extension rules, see [ARCHITECTURE.md](ARCHITECTURE.md).
Regression checks are documented in [tests/README.md](tests/README.md).

`Super+Q` toggles a panel on the focused monitor. Alternatively, rest the mouse
in the top-left or top-right corner of any screen for 400 ms to open the full
desktop panel on that screen. Each transparent sensor occupies only 6×6 logical
pixels of pointer input, reserves no workspace space and takes no keyboard focus.
Entering an armed corner shows a soft gradient that spreads and deepens across
96px during the 400 ms dwell, without a countdown ring. Leaving early fades the
hint away and cancels opening. The larger
visual is pointer-transparent outside the original 6×6 input region.
Passing through or holding a mouse button does not trigger it. Both corners only
open the panel; they never toggle an already-open panel closed. Closing with the
pointer still in a corner requires leaving and returning before another trigger.
Startup with the pointer already in a corner also stays silent. Adjust
`PanelHotCorners.qml`'s `dwellTime`/`cornerSize`, or set its `enabled` to false in
`shell.qml`, to tune or disable this entry. There is no bar. Each page sizes to its content, with one height ceiling:
`Theme.maximumPanelHeight` (700px by default), also limited by available screen
space. Width is capped at 680px. Height changes animate while the top edge
stays in place, and excess content scrolls without a scrollbar. Opening the panel
restores the last main tab (Desktop or System controls), including across shell
reloads and restarts. With no saved choice it starts on Desktop. System controls contains connectivity, audio,
brightness, appearance, power profiles, media and notifications. Both pages share
the search field, screen-keyboard button and compact footer. Device and notification
details use their own return/title header.

Desktop presents workspace cards with their windows visible together, using two
independently stacked columns when space permits and one on narrow screens.
Cards keep their column by workspace order rather than moving between columns
as their contents change. Workspace headers switch directly to their workspace;
the layout button beside each title exposes that workspace's layout choices.
Window rows show application icons and titles. Right-clicking a row or using its
ellipsis button opens the same inline actions for floating, fullscreen, moving
to another workspace and closing (with a second confirmation). Dragging windows
is not implemented. Clicking a window activates it and closes the panel after
the request succeeds. Actions target that window's address, even while the panel
holds keyboard focus. Lock screen is also available on Desktop.

Typing immediately searches applications, open windows and shell actions from either main tab.
System actions include settings pages, mute controls, appearance, keep-awake,
power profiles, the screen keyboard and locking. English titles and Chinese
keywords are searchable. Selection follows the result identity when live titles
change the ranking. Search and visible controls share `ShellActions.qml`;
services own state and asynchronous feedback. Window/workspace operations use
explicit targets through `HyprlandControls.qml`; searching for window management
opens Desktop to choose a target. Disabled actions cannot execute. Actions keep
the panel open, while navigation opens the corresponding page.
Results are ranked by prefix, word start, then substring; open windows rank highly
when their titles match. Clearing search returns to the selected tab. The footer
keeps the date, time, battery, volume, brightness and appearance summary visible;
battery details are available on hover.

- `Ctrl+N/P`: next/previous result.
- `Tab` / `Shift+Tab`: next/previous main tab while search is empty; typing
  continues in the shared search field. Search results, details and active input
  method composition keep their normal Tab handling.
- `Ctrl+A/E`: beginning/end of input; `Ctrl+F/B`: character forward/back.
- `Alt+F/B`: word forward/back; `Alt+D` / `Alt+Backspace`: kill next/previous word.
- `Ctrl+K/U`: kill to end/beginning; `Ctrl+W`: kill selection or previous word.
- `Ctrl+H/D`: backward/forward delete; `Ctrl+Y`: restore the last killed text.
- `Ctrl+G`: close. Vim-style result navigation is not used.
- Enter: launch an application or activate a window, then close.
- The keyboard button beside the search field shows/hides `wvkbd-mobintl`.
  Keep the panel open to type into search, or click outside to return to the
  previous application while leaving the keyboard available. The keyboard takes
  no keyboard focus, and the panel respects its reserved bottom area. Its own
  hide key also updates the button: visibility comes from Hyprland layer events
  and PID-filtered readback, not process lifetime. There is no periodic polling.
  It starts only on demand and exits with Quickshell; theme colours are supplied
  when starting the process. Missing `wvkbd-mobintl` disables the button; opening
  the panel rechecks availability after installation. Apply the NixOS configuration
  containing `pkgs.wvkbd` first. This is a manual desktop keyboard, not automatic
  input-field detection, a Chinese input method, or a login/lock-screen keyboard.
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
  and displays these shortcuts; they do nothing outside search or for missing results.
- Esc: clear search and return to the selected tab; leave details for System controls;
  on either main tab, close the panel.
  Super+Q again, Ctrl+G, or clicking outside closes from any page.
- Sliders: drag/click or use the wheel. Adjustments keep the panel open.
- System controls: persistent status notices, connectivity,
  volume/brightness and quick toggles come first,
  followed by the media card when a player is available, then the notification
  preview. Notifications show two recent entries with up to two body lines,
  a pending count, a separate Clear button and a history footer. The page
  scrolls when needed without showing a scrollbar.
  Opening or returning to System controls resets its scroll position for a fresh overview.
- Keep awake: toggle to inhibit automatic idle locking and screen power-off
  through Hypridle. The highlighted button stays active when the panel closes;
  toggle it off to restore idle timeouts. Quickshell exit/reload releases it.
  Uses the existing `systemd-inhibit` command; manual locking still works.
  While active, a notice near the top of the status page explains that automatic
  locking and screen power-off are paused, with a direct Turn off button.
  Muted microphones and outputs get similarly explicit notices and Unmute actions;
  these notices remain discoverable every time the panel opens.
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
  `$XDG_STATE_HOME/quickshell/notifications.json` (default `~/.local/state`) and survive restarts.
  If this file is absent, the notification module imports its previous per-shell
  cache file once; the old file is retained. An existing new file, including an
  empty history, always takes precedence. Notifications
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
While muted, the OSD shows MUTED alongside the stored volume, with warm
status text and progress; adjusting volume does not unmute it. Switching the focused
workspace shows the workspace numbers and application icons for one second on
the focused monitor, with the current workspace highlighted. This OSD reuses the
compact workspace summary, wraps within the screen width, and fades in/out with a
slight vertical motion. OSD windows use the overlay layer so feedback remains
visible over fullscreen applications; they do not accept input or keyboard focus.
Initial workspace discovery does not show a popup.

Microphone mute changes show `MICROPHONE · MUTED/UNMUTED`, including hardware
keys while the panel is closed. Switching the default audio output shows its
device name. Initial device discovery and changing input devices stay silent;
output changes settle for 180 ms, ignoring temporary missing nodes or rebuilding
the same device. These use the existing 1.5-second OSD, without input capture.
All OSDs share one card surface, border, radius and padding. Labels and primary
values align left; volume and brightness add a progress track below. Standard
cards are 320 logical pixels wide, capped to the available screen width. Device
names elide rather than widening the output OSD. Workspace feedback uses the
same outer card with an unframed workspace summary and retains content-driven
width and wrapping. Ordinary values use primary text, muted states use the warm
accent, and progress/selected workspaces carry the main accent.

Battery warnings enter the regular notification center at 20%, 10% and 5%
while discharging. The 20% banner expires normally; 10% and 5% are critical and
stay until dismissed or power is connected. Crossing several thresholds at once
shows only the most urgent one. Each threshold is announced once per observed
charge cycle, saved in `$XDG_STATE_HOME/quickshell/battery-alerts.json`, so shell
reloads do not repeat it. Charging resets the cycle and removes the pending
battery warning while keeping its history. If the shell missed an entire charge
cycle while stopped and restarts at 25% or less, it conservatively retains the
previous threshold; above 25% it recognizes the recharge.

Wi-Fi and Bluetooth connection feedback uses the same notification banners and
history. Connections requested from the panel report success or failure; an
established connection must remain disconnected for four seconds before a loss
is reported. Startup discovery, scanning, radio-off and disconnect actions from
the panel stay silent. Other tools' single-device disconnects may be reported
because the native API does not reliably expose their intent. Native Wi-Fi
failures also cover external connection attempts, with repeated reasons throttled
to one alert per 30 seconds. Bluetooth falls back to a
failed connection transition or timeout because its API exposes no failure reason.
Repeated updates for the same connection replace one notification record.
Wi-Fi switch suppression is scoped to the requesting adapter and released when
the attempt succeeds, fails or times out. Manual-disconnect suppression also
expires; a failed request cannot silence later connection-loss alerts forever.
Power-profile availability is checked against the D-Bus service at startup and
when opening the panel, without an additional persistent monitor process.

Each workspace also displays a compact marker for its actual Hyprland tiled
layout (D = dwindle, M = master, S = scrolling, O = monocle) beside its number,
in the compact workspace OSD; Desktop shows the full selected layout name.
Number and marker form a single 14px
semibold label, such as `3·S`, with width measured from its text and compact
spacing between application icons. The workspace OSD grows with its content up to the screen
width minus 64 pixels, wrapping only when that available width is exhausted.
Changing the focused workspace's tiled layout shows a separate 1.5-second OSD
with the full layout name and target workspace, including special workspaces.
Layout state is read from `hyprctl -j workspaces`, shared by the panel and OSD,
and refreshed on workspace, reload and custom layout events. Hyprland owns
layout changes; its custom event asks the shell to read back the result rather
than displaying the requested value optimistically. Reads superseded by an
event are discarded and retried. A three-second reconciliation catches changes
made by external commands. Initial discovery and selecting an unchanged layout
stay silent.

Hyprland keeps the existing general bindings and switches only the current
workspace's layout with `Super+Alt+D/M/S/O` for dwindle, master, scrolling,
and monocle respectively. Number bindings are reserved for workspaces.
When a special workspace is open, layout selection applies to it instead of
the regular workspace behind it.

Additional bindings:

| Binding | Dwindle | Master | Scrolling | Monocle |
| --- | --- | --- | --- | --- |
| `Super+H/K/J/L` | Directional focus | Directional focus | H/L focus columns; J/K directional focus | H/K previous, J/L next tiled window |
| `Super+Ctrl+H/L` | Resize width by −/+10 px | Same | Resize column by −/+5% of usable width and refit view | General resize dispatcher |
| `Super+N/P` | Next / previous workspace window | Same | Same | Next / previous tiled window |
| `Super+R` | Toggle split | Rotate master orientation | — | — |
| `Super+Return` | — | Toggle focus between master and previous window | — | — |
| `Super+Shift+Return` | — | Swap with master, focus master | — | — |
| `Super+W` / `Super+Shift+W` | — | — | Next / previous column-width preset | — |
| `Super+[` / `Super+]` | — | — | Swap whole column left/right | — |
| `Super+X` / `Super+Shift+X` | — | — | Pull next column's first window / expel current column's last window | — |
| `Super+O` / `Super+Shift+O` | — | — | Extract focused window / center column | — |
| `Super+D/E` | Preselect down/right split; Shift reverses | — | — | — |
| `Super+Alt+Space` | Clear split preselection | — | — | — |

`Super+T` opens the terminal; `Super+Q` toggles the launcher.
`Super+Shift+H/K/J/L` swaps tiled windows in that direction (except monocle),
or moves floating windows by 20 pixels.
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
| `Appearance.qml` | Apply observed Darkman mode to Hyprland colours |
| `DesktopServices.qml` | Audio devices, UPower, MPRIS, brightness and keep-awake controls |
| `SystemControls.qml` | Native network, Bluetooth and power objects, signals and actions |
| `DesktopSearch.qml` | Search, desktop-entry/icon lookup, window activation and application scopes |
| `Notifications.qml` | Notification daemon and local alerts: tracking, popup queue and history |
| `BatteryAlerts.qml` | Discharging thresholds, charge-cycle deduplication and persistence |
| `PanelState.qml` | Panel-owned last-main-tab persistence and load/write ordering |
| `ShellActions.qml` | Shared searchable action directory and dispatch for panel controls |
| `HyprlandControls.qml` | Explicit workspace/window operations and compositor state |
| `components/DesktopPage.qml` | Workspace browsing, layouts and targeted window actions |
| `components/DesktopWindowCard.qml` | Window activation and contextual controls |
| `ScreenKeyboard.qml` | On-demand wvkbd process and compositor-observed visibility |
| `components/LauncherPanel.qml` | Shared sizing, navigation, search selection and focus |
| `components/SearchResultsPage.qml` | Search result rendering and scrolling |
| `components/PanelHotCorners.qml` | Per-screen upper-corner dwell entry, without cursor polling |
| `components/HotCornerHint.qml` | Mirrored corner glow and dwell progress, without input handling |
| `components/WorkspaceLayoutState.qml` | Shared per-workspace layout state and change signals |
| `components/NotificationBanner.qml` | Screen-aware top-center notification stack |
| `components/NotificationCard.qml` | Shared popup, preview and history card layout |
| `components/NotificationUtils.js` | Icon URL normalization and persistent-image filtering |
| `components/StatusNotices.qml` | Persistent keep-awake and mute state, with direct recovery actions |
| `components/ConnectionFeedback.js` | Connection intent, settling and deduplicated outcomes |
| `components/StatusPage.qml` | Scrollable system controls, media and notification preview |
| `components/DesktopControls.qml`, `ControlTile.qml` | Connectivity cards with direct radio toggles |
| `components/ControlDetails.qml`, `DeviceRow.qml` | In-panel network/Bluetooth/audio detail views and device selection |
| `components/EmacsInput.qml` | Readline-style input editing and local kill buffer |
| `components/WorkspaceSummary.qml` | Used workspace numbers and application icons |
| `components/MediaCard.qml` | Media artwork, playback and timeline |
| `components/FilledSlider.qml`, `ChoiceButton.qml` | Shared controls |
| `components/StatusIcon.qml` | Palette-aware status icons without an icon-font dependency |
| `components/PanelFooter.qml` | Date/time, icon-based status summary and tray entries |
| `components/TrayMenuPopup.qml` | Themed DBusMenu entries and submenus |
| `components/OsdOverlay.qml` | Independent volume/brightness/microphone/output/workspace/layout feedback |
| `components/OsdCard.qml` | Shared OSD frame, text hierarchy and progress treatment |

Brightness reads use brightnessctl's native machine-readable output; kernel
backlight events trigger updates through udevadm. Slider writes are serialized,
rapid adjustments retain the latest target, and completion reads back the hardware
value. No custom watcher daemon or
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
- Application appearance requires Darkman and the Settings portal routed to it,
  as described below. The shell applies the observed preference to Hyprland;
  applications obtain it from the portal.
- Audio uses PipeWire, networking NetworkManager, Bluetooth BlueZ, battery
  UPower and power profiles power-profiles-daemon. Hardware-dependent controls
  can be absent. The current power-profile adapter does not reliably distinguish
  a missing daemon; provision it when using those buttons.
- The optional screen keyboard uses `wvkbd-mobintl` from `wvkbd` and Hyprland's
  virtual-keyboard/layer-shell protocols. It is installed by the Nix Hyprland module.
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
requirements. Other desktops may need different portal routing.

## Appearance ownership

Darkman is a runtime dependency: it schedules sunrise/sunset transitions and
publishes the standard `org.freedesktop.appearance/color-scheme` Settings portal
preference. GeoClue updates its location; Darkman recalculates transition times
as the date and location change. No fixed daily timetable is needed.

Quickshell watches `$XDG_RUNTIME_DIR/darkman/control.sock` and sends manual
choices through its `set` command. Manual choices do not disable the scheduler:
the next scheduled transition (or location update) can change the mode again.
There is one Darkman service for the session, not one process per shell instance.

The shell applies observed modes to its own palette and Hyprland, and saves a
snapshot in `$XDG_STATE_HOME/quickshell/appearance-mode` (default `~/.local/state`).
Hyprland reads that snapshot on startup/config reload. Quickshell restores it
before connecting, then accepts Darkman's live mode; it never sends the old
snapshot back to Darkman. While Darkman is unavailable, the last palette remains
visible, manual controls are disabled, and the shell retries the connection.

Application preferences come directly from Darkman's Settings portal; Quickshell
does not write `gsettings`. Fixed GTK/Qt themes and application styles are not
rewritten. Applications must support and follow the portal preference.

The Nix module installs Darkman, routes the Settings portal to it, and enables
GeoClue with a location agent. Apply the NixOS configuration and start a fresh
graphical session after changing portal providers. A user-local
`~/.config/darkman/config.yaml` overrides the system configuration. Without a
known location, automatic transitions cannot run; check the Darkman logs for
location errors and the next sunrise/sundown times.

Quickshell starts from the dotfiles-owned service, which wants Darkman but can
retain its last palette if the dependency fails. Check:

```sh
darkman get
quickshell ipc call appearance status
quickshell ipc call appearance setMode dark
journalctl --user -u darkman.service -u quickshell.service -b
gdbus call --session --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.ReadOne \
  org.freedesktop.appearance color-scheme
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
