-- Autostart (exec-once equivalent)
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
  hl.exec_cmd("systemctl --user start hypridle.service")
  hl.exec_cmd("systemctl --user start hyprmoncfgd.service")
  hl.exec_cmd("systemctl --user start quickshell.service")
  hl.exec_cmd("clipse -listen")
  hl.exec_cmd("udiskie")
  hl.exec_cmd("hyprpaper")
  -- Fcitx5 starts through XDG Autostart (handled by UWSM in this session).
  -- Do not also launch it here: --replace races with the session's instance.
end)
