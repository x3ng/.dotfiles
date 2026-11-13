-- Per-application window and layer rules
-- Add app-specific overrides here to keep rules.lua generic.

-- Screenshot annotation should not rearrange the tiled workspace.
hl.window_rule({
  match = { class = "^com\\.gabm\\.satty$" },
  float = true,
  center = true,
})

-- Clipboard history uses a dedicated Kitty class from the Super+V binding.
hl.window_rule({
  match = { class = "^clipse$" },
  float = true,
  center = true,
})

-- WPS Office (XWayland)
-- no_focus prevents Hyprland from stealing focus when popups appear,
-- which stops WPS from auto-closing its own toolbars/menus.
hl.window_rule({
  match = { class = "^wps$" },
  float = true,
  no_focus = true,
})
