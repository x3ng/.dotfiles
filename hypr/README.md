# Hyprland session

These Lua configs target Hyprland 0.57.0. Validate changes without starting a
second compositor with `Hyprland --verify-config -c "$PWD/hypr/hyprland.lua"`
from the repository root.

Workspace identity uses Lua `addressable_name` and IPC/Quickshell `address`.
Named and special workspaces do not have numeric IDs in 0.57.

Hyprland owns window management and key bindings. nullshell owns launcher,
notifications, OSD, wallpaper and idle policy; `Super+Q` calls its launcher IPC endpoint.
`startup.lua` directly starts independent desktop, locker, Polkit and sleep-bridge
processes. Quickshell uses `--no-duplicate`; no nullshell keepalive units are used.
The `nullshell` launcher uses native Quickshell named configuration discovery;
these dotfiles do not locate or deploy its QML.
Do not start another desktop, notification owner or authentication agent alongside it.
Install nullshell and its system integration before using these configs.

`Super+N/P` traverses windows, including floats. Monocle uses native Lua
window enumeration so its inactive tiles are included too; other layouts use
the built-in window cycle. Hidden group tabs stay on `Super+Alt+N/P`.
`workspaces.lua` implements these key binding actions; nullshell ships its own
compositor adapter for panel actions.

Focus a floating window and hold `Super+Shift+H/J/K/L` to move continuously
in 20px steps. `Super+Space` toggles floating. For longer adjustments,
press `Super+R`, then release Super. In this Sway-inspired
`float-adjust` submap, hold `H/J/K/L` to move left/down/up/right in 20px steps.
Hold `Ctrl+H/L` to shrink/grow width and `Ctrl+J/K` to shrink/grow height in 10px
steps, matching the existing global resize bindings. `Enter` or `Esc` exits;
unrelated keys are consumed so they do not type into the application. A native
notification shows the controls on entry. If focus changes or the target closes,
the next adjustment exits without changing another window. On tiled windows,
`Super+R` retains its layout orientation action. Mouse dragging remains available.
This follows Sway's enter-adjust-exit pattern, extending its resize mode with
movement and keeping this configuration's HJKL/Ctrl vocabulary:
https://github.com/swaywm/sway/blob/master/config.in

`Super+Alt+D/M/S/O` selects dwindle/master/scrolling/monocle for the active
workspace, with a visible special workspace taking precedence. The binding
applies a native workspace rule. There is no synthetic layout event or layout
polling: nullshell refreshes labels when the panel opens, after panel actions,
and on native workspace/configuration events. Hyprland 0.57.0 exposes no tiled-layout
change event, so these bindings do not trigger an OSD. On configuration reload,
`workspaces.lua` snapshots existing workspaces' live layouts and reapplies their rules before Hyprland's
deferred layout refresh. This preserves choices from both the key bindings
and the panel when monitor profiles change (including lid-related reloads),
without depending on nullshell. Numeric, named and special workspaces use
their native `addressable_name` selectors. The snapshot is restored before
`rules.lua` and `monitor.lua`: an explicit layout in those rules takes
precedence. Layout-only rules merge with other settings such as gaps,
monitor binding and persistence.

Applying a runtime workspace rule also refreshes every persistent workspace's
monitor placement in Hyprland 0.57.0. Before the shared layout action applies its
rule, it updates existing persistent workspaces' monitor rules to their live
locations, preserving manual moves even when another workspace changes layout.
These monitor overrides last until reload; loading a monitor profile restores
its configured assignments.

Layout choices belong to the current session. Rules remain active until
the next configuration reload, so destroying a workspace and recreating
the same selector can reuse its chosen layout. On reload, only existing
workspaces are captured; absent workspaces lose their runtime rules.
New selectors and a new Hyprland session use the configured default or
explicit workspace rules. Changing only the global default preserves
existing workspaces' selected layouts; an explicit per-workspace layout
overrides them. Only the four built-in layouts above are preserved.

This preserves the layout algorithm, not a saved window arrangement. It
cannot recover a workspace destroyed before the snapshot, or recover from
a compositor restart. Live workspace names are captured anew on every
reload. Renaming a workspace without reloading does not migrate its old
runtime selector rule; that is Hyprland's native rule behavior.

nullshell owns manual/automatic appearance and publishes it through its Settings
portal backend. It applies compositor colours through its loaded
compositor adapter and saves a snapshot. On startup/config reload,
`appearance.lua` reads that snapshot; missing or invalid state falls back to
the dark palette. The compositor palette is defined locally.

Window styling follows the shell's neutral grey and muted blue palette, with 4px inner / 8px
outer gaps, 4px corners and a soft 12px shadow. Compositor opacity multipliers stay at 1.0; applications may supply transparency.
Grouped-window titles use the same Inter family as the panel.

`monitor.lua` owns display setup: preferred modes, automatic position and scale
are the native baseline. Hyprland loads a confirmed layout when the connected
outputs match one saved through nullshell, even when the shell is not running.
There is no separate monitor daemon or second static Lua file to load.
Use **Display settings** in the shell to edit and confirm a layout.

These configs expect a session manager with XDG Autostart support, such as
UWSM. Fcitx5 is started by its `org.fcitx.Fcitx5.desktop` autostart entry,
not by `startup.lua`. Install Fcitx5, the desired input engines, and the
GTK/Qt input method modules using the distribution's packages.

On Nix/Home Manager, keep the input method package and toolkit integration,
but set `i18n.inputMethod.fcitx5.systemd.enable = false` to avoid starting a
second instance alongside XDG Autostart.

On another distribution, check that the package supplies an entry in an
XDG `autostart` directory; a launcher in `share/applications` alone does not
autostart. If needed, create `~/.config/autostart/org.fcitx.Fcitx5.desktop`
with `Type=Application`, `Name=Fcitx 5`, and `Exec=fcitx5` under
`[Desktop Entry]`. Avoid links to version-specific package paths.

If launching Hyprland without an XDG Autostart manager, configure one
Fcitx5 startup mechanism for that session instead. Do not combine a manual
launch with another enabled autostart entry or Fcitx5 user service.

## Idle and lock

nullshell owns dim/lock/display-off timers and the Keep awake control. Its
`nullshell sleep-bridge` runs the Rust helper for logind lock/suspend coordination.
It waits for compositor lock confirmation before releasing the sleep delay
inhibitor; failures remain subject to logind's maximum delay. On resume it rearms
the inhibitor and requests display power on. Do not start another sleep bridge.
Edit timers in **Idle and sleep settings** in the shell; system lid and power-key
policy is independent of these Lua files.

## Desktop component ownership

The compositor launches desktop, locker, Polkit and sleep bridge separately.
`Super+Q` calls `nullshell ipc call launcher toggle`; `Super+M` calls `nullshell lock`.
The locker owns PAM authentication and remains independent of desktop reloads.
No supervisor automatically restarts Quickshell. Use its native log/IPC commands
for diagnostics. Clients terminate when Wayland disconnects; UWSM also handles
session cgroup cleanup. The old `nullshell*.service` and target must not
be enabled alongside these direct processes. If migrating from a setup that used
those units, remove them through their original configuration owner, then log out
and back in rather than starting the new stack in the old session.

This package does not deploy personal shell preferences, state, greeter
resources or system integration.

The existing `quickshell-launcher` and `quickshell:osd` layer namespaces are
retained by nullshell, so their compositor animation rules remain intentional.
There is no active Hyprlock, Hyprpaper or standalone hypridle configuration here.
The installer removes only obsolete symlinks owned by this repository, preserving
independent user files. Window rules, input settings and key bindings remain
compositor configuration; confirmed monitor layouts are separate user data.
