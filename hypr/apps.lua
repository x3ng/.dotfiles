-- Per-application window and layer rules
-- Add app-specific overrides here to keep rules.lua generic.

-- WPS Office (XWayland)
-- no_focus prevents Hyprland from stealing focus when popups appear,
-- which stops WPS from auto-closing its own toolbars/menus.
hl.window_rule({
  match = { class = "^wps$" },
  float = true,
  no_focus = true,
})

-- Quickshell uses a layer-shell surface rather than a normal window.  Window
-- blur rules do not affect it, so give its namespace the acrylic treatment
-- explicitly.  The QML surfaces remain translucent and provide the tint.
hl.layer_rule({
  match = {
    namespace = "quickshell",
  },
  blur = true,
  blur_popups = true,
  -- Respect transparent holes between the three bar surfaces.
  ignore_alpha = false,
})
