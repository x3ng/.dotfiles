-- Autostart (exec-once equivalent)
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprmoncfgd.service")
  -- Owns desktop, locker, Polkit and the retained hypridle sleep bridge.
  hl.exec_cmd("nullshell session-start")
  hl.exec_cmd("clipse -listen")
  hl.exec_cmd("udiskie")
  -- Fcitx5 starts through XDG Autostart (handled by UWSM in this session).
  -- Do not also launch it here: --replace races with the session's instance.
end)
