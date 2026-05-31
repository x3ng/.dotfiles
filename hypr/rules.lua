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

-- hyprland-run positioning
hl.window_rule({
  match = { class = "hyprland-run" },
  float = true,
  move = { 20, "monitor_h-120" },
})

-- Waybar layer blur
hl.layer_rule({
  match = { namespace = "waybar" },
  blur = true,
  ignore_alpha = 0.2,
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
