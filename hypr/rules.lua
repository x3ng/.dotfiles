-- Suppress maximize events from all apps
hl.window_rule({
  match = { class = ".*" },
  suppress_event = "maximize",
})

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
