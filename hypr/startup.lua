-- Autostart (exec-once equivalent)
hl.on("hyprland.start", function()
  -- Sleep/logind bridge only; Quickshell owns the idle timers.
  hl.exec_cmd("systemctl --user start hypridle.service")
  hl.exec_cmd("systemctl --user start hyprmoncfgd.service")
  -- Also starts the independent locker and Polkit agent through Wants=.
  hl.exec_cmd("systemctl --user start quickshell.service")
  hl.exec_cmd("clipse -listen")
  hl.exec_cmd("udiskie")
  -- Fcitx5 starts through XDG Autostart (handled by UWSM in this session).
  -- Do not also launch it here: --replace races with the session's instance.
end)
