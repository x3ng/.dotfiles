-- Autostart (exec-once equivalent)
hl.on("hyprland.start", function()
  -- Start independent shell components once; native config discovery is external.
  hl.exec_cmd("nullshell locker --no-duplicate")
  hl.exec_cmd("nullshell polkit --no-duplicate")
  hl.exec_cmd("nullshell desktop --no-duplicate")
  hl.exec_cmd("nullshell sleep-bridge")
  hl.exec_cmd("clipse -listen")
  hl.exec_cmd("udiskie")
  -- Fcitx5 starts through XDG Autostart (handled by UWSM in this session).
  -- Do not also launch it here: --replace races with the session's instance.
end)
