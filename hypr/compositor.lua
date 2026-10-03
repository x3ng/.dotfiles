-- Global Hyprland behavior and appearance.
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
    border_size = 2,
    ["col.active_border"] = {
      -- Keep the compositor chrome neutral; Quickshell owns the UI palette.
      colors = { "rgba(f0f0f0ee)", "rgba(b8b8b8ee)" },
      angle = 45,
    },
    ["col.inactive_border"] = "rgba(707070bb)",
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding = 5,
    rounding_power = 2,
    -- Keep application windows opaque; reserve backdrop blur for translucent shell surfaces.
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(000000cc)",
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      -- Quickshell provides its own tint; avoid extra color and grain here.
      vibrancy = 0.0,
      noise = 0.0,
    },
  },

  input = {
    kb_layout = "us",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = false,
    },
  },

  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
  },

  dwindle = {
    preserve_split = true,
  },

  master = {
    new_status = "master",
  },

  -- Grouped windows share one tiled slot; the groupbar labels each tab.
  group = {
    ["col.border_active"] = "rgba(f0f0f0ee)",
    ["col.border_inactive"] = "rgba(707070bb)",
    ["col.border_locked_active"] = "rgba(b8b8b8ee)",
    ["col.border_locked_inactive"] = "rgba(505050bb)",
    groupbar = {
      enabled = true,
      gradients = true,
      blur = true,
      render_titles = true,
      scrolling = true,
      height = 24,
      font_size = 12,
      text_padding = 6,
      rounding = 4,
      gradient_rounding = 4,
      indicator_height = 0,
      indicator_gap = 0,
      text_color = "rgba(ffffffff)",
      ["col.active"] = "rgba(686868e8)",
      ["col.inactive"] = "rgba(1d1d1de0)",
      ["col.locked_active"] = "rgba(7a7a7ae8)",
      ["col.locked_inactive"] = "rgba(2c2c2ce0)",
    },
  },

  xwayland = {
    force_zero_scaling = true,
  },
})

-- Bezier curves
hl.curve("easeOutQuint",  { type = "bezier", points = { { 0.23, 1 },   { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0,    0 },    { 1,    1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5,  0.5 },  { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1,  1 } } })

-- Animations
hl.animation({ leaf = "global",       enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",       enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",      enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",    enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",       enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",      enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",         enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",       enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",     enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",    enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut",enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",   enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut",enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",   enabled = true, speed = 7,    bezier = "quick" })

-- Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
