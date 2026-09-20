-- Per-application window rules
-- Add app-specific overrides here to keep rules.lua generic.

-- WPS Office (XWayland)
-- no_focus prevents Hyprland from stealing focus when popups appear,
-- which stops WPS from auto-closing its own toolbars/menus.
hl.window_rule({
  match = { class = "^wps$" },
  float = true,
  no_focus = true,
})
