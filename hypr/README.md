# Hyprland session

These Lua configs target Hyprland 0.56.2. Validate changes without starting a
second compositor with `Hyprland --verify-config -c "$PWD/hypr/hyprland.lua"`
from the repository root.

Hyprland owns window management and key bindings. Quickshell owns launcher,
notifications and OSD presentation; `Super+Q` calls its launcher IPC endpoint.
`startup.lua` starts the Quickshell user service, so systemd owns its lifetime
and restart policy. Do not also run a separate `quickshell` startup command.

`Super+Alt+D/M/S/O` selects dwindle/master/scrolling/monocle for the active
workspace, with a visible special workspace taking precedence. The binding
applies a native workspace rule. There is no synthetic layout event or layout
polling: Quickshell refreshes labels when the panel opens, after panel actions,
and on native workspace/configuration events. Hyprland 0.56.2 exposes no tiled-layout
change event, so these bindings do not trigger an OSD. On configuration reload,
`hyprland.lua` snapshots existing workspaces' live layouts and reapplies their rules before Hyprland's
deferred layout refresh. This preserves choices from both the key bindings
and the panel when monitor profiles change (including lid-related reloads),
without depending on Quickshell. Numeric, named and special workspaces use
their native `config_name` selectors. The snapshot is restored before
`rules.lua` and monitor profiles: an explicit layout in those modules takes
precedence. Layout-only rules merge with other settings such as gaps,
monitor binding and persistence.

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

Darkman owns the appearance mode. Quickshell applies its observed mode through
`appearance.lua` and saves a snapshot for compositor startup/config reload.
Missing or invalid saved state falls back to the dark palette. The adapter's
explicit `apply("dark")` / `apply("light")` interface is shared with Quickshell;
keep the palettes in sync with `quickshell/Theme.qml`.

Window styling follows the shell's muted green palette, with 4px inner / 8px
outer gaps, 10px corners and a soft 18px shadow. Compositor opacity multipliers stay at 1.0; applications may supply transparency.
Grouped-window titles use the same Inter family as the panel.

Run `hyprmoncfg` to arrange displays and save profiles. `startup.lua` starts
`hyprmoncfgd.service` to switch saved profiles automatically. Before a
profile is applied, displays use their preferred mode with automatic
position and scale.

Profiles live in `~/.config/hyprmoncfg/profiles/`. The generated
`~/.config/hypr/monitors.lua` stays outside this repository and is loaded
only when present. Keep the literal `require("monitors")` in
`hyprland.lua` so hyprmoncfg can verify the loading path.

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

Hypridle dims the laptop backlight after 150 seconds, locks at 300 seconds
and powers off displays at 600 seconds. Activity restores the saved brightness
and display power. Inhibitors, including Quickshell's Keep awake control,
continue to suppress idle actions. No automatic suspend timeout is added.
Before system sleep, logind requests the configured lock command and hypridle
waits for the session-lock confirmation. Display power commands use the
Hyprland 0.56 Lua dispatcher syntax.

Hyprlock uses a dimmed screenshot background, reduced blur, a light-weight Inter clock and date,
keyboard layout, and a wider password field with authentication, failure and
Caps Lock feedback. Its input field uses the shell's dark colours for contrast
over screenshots; keep those native colour values in sync with `Theme.qml`.
