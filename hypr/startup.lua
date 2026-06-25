-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Monitor (auto-detect all, preferred resolution)
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1.0,
})

-- Autostart (exec-once equivalent)
hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
  hl.exec_cmd("quickshell")
  hl.exec_cmd("mako")
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("blueman-applet")
  hl.exec_cmd("pasystray")
  hl.exec_cmd("fcitx5 -d --replace")
  hl.exec_cmd("clipse -listen")
  hl.exec_cmd("wl-paste --watch cliphist store")
  hl.exec_cmd("udiskie")
  hl.exec_cmd("hyprpaper")
end)

-- Per-device input config — uncomment and set your device name
-- Find device names with: hyprctl devices
-- hl.device({
--   name = "your-mouse-name",
--   sensitivity = -0.5,
-- })
