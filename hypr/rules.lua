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

-- These shell surfaces already animate opacity in QML. A second compositor
-- fade multiplies that animation and adds another fade after QML unmaps them.
hl.layer_rule({
  match = { namespace = "^(quickshell-launcher|quickshell:osd)$" },
  no_anim = true,
})

-- "Smart gaps" / "No gaps when only" — uncomment to enable
-- hl.workspace_rule({
--   workspace = "w[tv1]",
--   gaps_out = 0,
--   gaps_in = 0,
-- })
-- hl.workspace_rule({
--   workspace = "f[1]",
--   gaps_out = 0,
--   gaps_in = 0,
-- })
