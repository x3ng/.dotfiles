# Hyprland session

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
