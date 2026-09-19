-- Environment variables
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
hl.env("GTK_ICON_THEME", "Papirus")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Autostart (exec-once equivalent)
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
  hl.exec_cmd("systemctl --user start hypridle.service")
  hl.exec_cmd("systemctl --user start hyprmoncfgd.service")
  hl.exec_cmd("noctalia-shell")
  hl.exec_cmd("clipse -listen")
  hl.exec_cmd("udiskie")
end)

-- Per-device input config — uncomment and set your device name
-- Find device names with: hyprctl devices
-- hl.device({
--   name = "your-mouse-name",
--   sensitivity = -0.5,
-- })
