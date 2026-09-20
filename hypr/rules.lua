-- Fix dragging issues with XWayland
hl.window_rule({
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

-- Center floating dialogs to prevent submenu/popup mispositioning
hl.window_rule({
  match = { float = true, modal = true },
  center = true,
})

-- "Smart gaps" / "No gaps when only" — uncomment to enable
-- hl.workspace_rule({
--   match = { workspace = "w[tv1]" },
--   gaps_out = 0,
--   gaps_in = 0,
-- })
-- hl.workspace_rule({
--   match = { workspace = "f[1]" },
--   gaps_out = 0,
--   gaps_in = 0,
-- })
