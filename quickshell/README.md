# Quickshell desktop panel

## Login and lock screen

The desktop, lock screen, and greeter share `Theme.qml` and `LoginView.qml`.
They are separate Quickshell processes: the desktop runs as the user, the locker
runs in the user's existing Wayland session, and greetd starts the greeter as
`greeter` in a private Cage session. The greeter lists the installed Wayland
sessions and prefers Hyprland UWSM on this host.
The locker uses a dark frosted surface over the shared blurred wallpaper; the
greeter uses a system-deployed dark theme and never reads the user's state.

Preview the common login view in a normal window, without authentication or
locking the session:

```bash
./quickshell/preview.sh greeter
./quickshell/preview.sh lock
```

`QS_PREVIEW_LIGHT=1 ./quickshell/preview.sh greeter` checks the greeter light palette.
The preview exercises only the visual layer; the greetd and PAM paths need one
real login and lock test after deployment.

`IdlePolicy.qml` owns the desktop's 150-second dim, 300-second lock, and
600-second display-off timers. The command panel's Keep awake control suspends
those timers. Hypridle has no idle listeners; it remains for sleep and external
session-lock requests, which need logind's lock handshake.

Deploy the greeter QML explicitly from the dotfiles root with
`./quickshell/install.sh install-greeter`. This copies only the four public QML
files it needs to `/etc/xdg/quickshell/greeter`; it does not expose the user's
home directory to the greeter. `./quickshell/install.sh install` links the user
locker and `qs-lock` command. Install the greeter files before the NixOS switch;
install the user locker after the switch creates `/etc/pam.d/quickshell-lock`.
The NixOS greeter command is declared in `nix-config/software/hyprland.nix`.
It starts Cage and Quickshell directly. Install the QML files before activating
the NixOS change; use another TTY to recover if the greeter cannot start.

To activate the NixOS change without restarting the active greetd service,
run `nh os boot path:.` in `nix-config` after installing the greeter files,
then reboot. A normal `nh os switch path:.` also works but can interrupt the
current graphical session when greetd changes.

Because a conforming compositor stays locked if the locker crashes, test the
new locker from a session where another TTY is available. Before the PAM service
is installed, `qs-lock` exits without locking the session.

A barless desktop panel for Hyprland. `Super+Q` toggles it; each opening starts
on Status. The upper screen corners also open it after a dwell, configured in
`components/PanelHotCorners.qml`.

## Status and navigation

Status is the compact default view: Wi-Fi and Bluetooth connection summaries,
volume and brightness, a workspace strip, recent notification preview, and playback
controls when a player exists. Search receives focus immediately on opening.

- Connection entries open device details; radio toggles remain in those pages and search.
- The workspace strip shows numbers and up to three application icons per workspace;
  extra windows appear as a count. Click a workspace to switch; the adjacent window
  button opens management. The strip scrolls horizontally when needed.
- Workspaces stack vertically in one column. Inside each workspace, window cards
  flow horizontally at content-based widths, capped to the row width, and wrap naturally. Window search results include their workspace location.
- The headphones button opens audio device selection; the speaker toggles mute.
- Empty input shows time, date and battery beside clickable scope hints. Typing
  or composing text replaces the status with the query; clearing restores it.
  The latest pending notification has its own compact row opening the center.
- The footer groups icon-only appearance, keep-awake, lock and tray controls.
- Power profiles, microphone mute, wallpaper and screen keyboard remain searchable commands.
- Detail pages share a back/title header. Back or Esc returns to Status; Esc on
  Status closes the panel. Clicking outside, `Super+Q` or `Ctrl+G` also closes it.

The panel has a maximum width of 680px and fits screen width minus 32px. Its top
edge stays at about 18% of the available height. Height follows the content up to
700px or available space; overflow scrolls. Panel geometry is in
`components/LauncherPanel.qml`; shared colors and typography remain in `Theme.qml`.

## Search and keyboard

Typing in Status searches applications, open windows and shell actions. Ranking
prioritizes exact names, prefixes, words and substrings over metadata; all query terms must match.
Use `>` for commands, `@` for windows and `/` for applications (`apps:` is also accepted). A bare prefix
lists its catalog. Search covers these three sources, not files or arbitrary shell commands. Search and visible controls share
`ShellActions.qml`; disabled actions cannot execute.

| Input | Action |
| --- | --- |
| Enter | Activate the selected result |
| Shift+Enter | Launch an application in the configured terminal |
| Ctrl+N / Ctrl+P | Next / previous result |
| Ctrl+1…9, Ctrl+0 | Activate results 1–10 |
| Tab / Shift+Tab | Move keyboard focus without changing pages |
| Ctrl+A / Ctrl+E | Beginning / end of input |
| Ctrl+F / Ctrl+B | Forward / backward character |
| Alt+F / Alt+B | Forward / backward word |
| Alt+D / Alt+Backspace | Kill next / previous word |
| Ctrl+K / Ctrl+U | Kill to end / beginning |
| Ctrl+W | Kill selection or previous word |
| Ctrl+H / Ctrl+D | Backward / forward delete |
| Ctrl+Y | Restore the last killed text |

Application and window activation close the panel; settings actions keep it open.
Terminal desktop entries use `DesktopSearch.terminalCommand`, defaulting to
`["kitty", "--"]`. Applications run in independent systemd user scopes, so a shell
restart does not terminate them. Desktop-entry arguments and working directories
are passed without constructing a shell command string.

The keyboard button toggles `wvkbd-mobintl`. It is started on demand, takes no
keyboard focus and exits with Quickshell. Visibility is observed through Hyprland
layer events/readback. It is a manual desktop keyboard, not an input method or
lock-screen keyboard.

## Windows and devices

The workspace manager shows workspace cards in one ordered column. Workspace
headers switch workspace; their layout controls select dwindle, master, scrolling
or monocle. Window rows activate the selected window. Right-click or the ellipsis
opens floating, fullscreen, move and close actions; close requires confirmation.
Requests use explicit workspace addresses/window addresses and dismiss only after the
matching successful completion.

Workspace identity uses Quickshell/IPC `address` and Lua `addressable_name`,
including named and special workspaces without numeric IDs. Existing targets
are resolved again at execution time; missing numbered targets 1–10 can still
be opened from the panel. Layout changes preserve live persistent-workspace
monitor assignments until configuration reload. The panel and keyboard bindings
share `hypr/workspaces.lua`; deploy it with the other Hyprland modules.

Wi-Fi details list nearby networks and support personal passwords, connect,
disconnect and confirmed forget. Advanced or hidden-network setup opens `nmtui`.
Scanning runs only while Wi-Fi details are open. Bluetooth supports bounded
discovery, pairing prompts, connect/disconnect and confirmed forget. Leaving the
Bluetooth detail page cancels an in-progress pairing agent.

Audio details select output/input devices. Media controls show artwork/title and
previous/play-pause/next; there is no player selector or seek control. Keep-awake
inhibits automatic dimming, locking and screen power-off until disabled. The
choice persists across reloads and login; manual locking remains available.

## Notifications

Quickshell owns `org.freedesktop.Notifications`. Do not run another notification
daemon alongside it. Banners appear on the focused monitor, with at most four
visible cards. Normal timeout defaults to five seconds; critical/zero-timeout
banners remain until closed. Hover pauses expiry. Banner expiry hides presentation
without invalidating live actions; explicit dismissal closes the notification.

The center has Pending and History views. Clear all dismisses pending entries and
keeps history. Clear history removes stored entries and matching pending entries.
Per-entry actions and clear controls are next to the displayed list. Bulk-clear
intent also applies to history that is still loading from disk.

Titles/bodies use plain text. Cards support wrapped actions, attached images and
expandable content. A live default action opens the notification; archived records
with a valid desktop-entry hint can open the application, not the original message.
Sender closure invalidates live actions. Resident notifications remain live after
an action when requested by the sender.

Pending entries are capped at 20 and history at 50. Display data is saved in
`$XDG_STATE_HOME/quickshell/notifications.json` (default `~/.local/state`). Live
objects/actions and in-memory image handles are not persisted.

## OSD and appearance

OSD covers volume, brightness, microphone mute, output-device changes, regular
workspace switches and window moves. It uses native service/compositor updates;
backlight changes use kernel events. Workspace feedback shows workspace names,
layout markers and app icons. Special-workspace open/close has no dedicated OSD.

Hyprland 0.57.0 has no native tiled-layout change event; `activelayout` is a keyboard
layout event. Layout labels read `HyprlandWorkspace.lastIpcObject.tiledLayout`. Native snapshots
are refreshed on workspace/configuration events, when the panel opens and after
panel operations, without a separate `hyprctl` reader. There is no layout polling or
synthetic event, and changing the tiling algorithm does not trigger an OSD.

`Theme.qml` defines colour, spacing, radius and motion tokens. The launcher uses
200ms entrance / 140ms exit; OSD uses 100ms / 80ms. Hyprland layer rules disable a
second compositor animation for these two surfaces. Panel and card surfaces are
opaque; accents are limited to state and keyboard focus. Hyprland colours are
mirrored in `hypr/appearance.lua`.

For module ownership, route dispatch, service lifetimes and persistence, see
[ARCHITECTURE.md](ARCHITECTURE.md).

## Deployment

```sh
./hypr/install.sh install
./quickshell/install.sh install
systemctl --user restart quickshell.service
hyprctl reload
```

The installer links every root QML module and the components directory, and
links the user service. Hyprland starts the service from `hypr/startup.lua`;
systemd restarts it on failure and stops it with the graphical session. Uninstall
only removes links owned by this package and only stops its own linked service.

```sh
quickshell ipc call launcher toggle
quickshell ipc call launcher close
systemctl --user status quickshell.service
quickshell log --tail 50
```

## Portability and dependencies

This is a reusable **Hyprland/Linux** shell configuration, not a compositor-
independent desktop shell. The greeter currently pre-fills the personal username
in `greeter/shell.qml`; change it when reusing the configuration. No monitor
connector or literal Nix store path is embedded in QML. State uses XDG directories; layout sizes, palettes and
limits are personal defaults that can be adjusted in QML.

- Require Quickshell 0.3.2 APIs and their Qt modules, Hyprland 0.57 with the Lua
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
  can be absent. Power-profile availability is probed at startup and panel opening.
  Bluetooth pairing additionally needs `python3`, `bluetoothctl` and `busctl` in
  the shell service PATH; no third-party Python package is needed.
- The optional screen keyboard probes `wvkbd-mobintl -v` once per shell load
  (reload after installing it). It uses `wvkbd-mobintl` from `wvkbd` and Hyprland's
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

## Wallpaper

Quickshell draws a static background layer for each connected display. The
command panel's **Choose wallpaper** search action opens the image picker. Choose all
displays or one output, select Fill/Fit/Stretch, then Apply. Applying to all
displays clears saved output overrides. Disconnecting a display preserves its
choice for reconnection.

`wallpaper.json` contains defaults; the initial image is `~/Pictures/mystic_forest.png`. User selections are atomically saved
to `$XDG_STATE_HOME/quickshell/wallpaper.json` (normally
`~/.local/state/quickshell/wallpaper.json`). Desktop and locker watch the same
state. Missing images use a solid background. Lock screens use the matching
output's image with a dark overlay; greeter deployment is independent.

Hyprpaper is no longer started by the Hyprland configuration. Quickshell's
background windows follow display hotplug and request no keyboard focus or
exclusive area. Images decode asynchronously at display-sized resolution.

### Lock screen standby

`quickshell.service` wants the independent `quickshell-lock.service`. It preloads
wallpapers asynchronously and waits for `qs-lock` to call the lock-only IPC
method; successful PAM authentication clears credentials and returns to standby.
No unlock IPC is exposed. `qs-lock` starts the systemd service if needed and
waits a bounded time for its IPC handler; it never spawns an unmanaged locker.
Native-size decoded images stay in the lock process cache.
The lock wallpaper uses Qt Quick MultiEffect blur, a dark tint, and a translucent
card; the desktop and greeter retain their own appearance settings.

QML hot reload is disabled in the locker so a reload cannot reset lock state.
After editing lock QML, unlock first, then run
`systemctl --user restart quickshell-lock.service`. For safe visual iteration,
use `./quickshell/preview.sh lock`. Do not restart the service while locked.

### Polkit authentication

An independent `quickshell-polkit.service` provides the user-session Polkit
authentication dialog, using `Quickshell.Services.Polkit`. The system Polkit
authority continues to enforce policy; the agent does not run as root or alter
authorization rules. `quickshell.service` starts it as a dependency. Its unit
conflicts with `hyprpolkitagent.service` so only one agent registers.

The dialog supports identity selection, hidden/visible prompts, retries,
cancellation (Cancel or Escape), and clears the input after each response.
Queued requests and requester cancellation are handled by Quickshell's Polkit
module. It appears on the focused monitor. No credentials are sent over IPC.

Preview without registering another agent:
`quickshell --path ~/.config/quickshell/polkit/preview.qml`.
Preview responses deliberately show a retry; Cancel closes the preview.
Inspect registration with
`quickshell ipc --path ~/.config/quickshell/polkit call polkit status`.
QML hot reload is disabled; restart `quickshell-polkit.service` after edits
when no authorization request is active.

Service lifecycle checks: the installer preflights lock and authentication state
before uninstalling any component. Unknown or active state blocks uninstall.
Idle policy restores brightness and output power when the desktop shell reloads
or exits normally. A process crash cannot run this cleanup.

Keep awake is persisted in `$XDG_STATE_HOME/quickshell/keep-awake` (normally
`~/.local/state/quickshell/keep-awake`). Both on and off survive reload, service
restart and login. Idle monitors remain disabled until the saved choice has
loaded; the choice is independent of the transient systemd-inhibit process.
The setting pauses automatic idle behavior, not explicit suspend or lid policy.
`quickshell ipc --path ~/.config/quickshell call idle status` reports the saved
intent and the running inhibitor separately.
