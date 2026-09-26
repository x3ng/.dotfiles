local terminal = "kitty"
local menu = "rofi -show combi"

-- ══════════════════════════════════════════════════════════════
-- Hyprland 原生快捷键（窗口/工作区/布局管理）
-- ══════════════════════════════════════════════════════════════

-- Launch & window controls
hl.bind("SUPER + Q", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + P", hl.dsp.window.pseudo({ action = "toggle" }))
-- Pin toggles visibility across workspaces on this monitor; the window must be floating.
hl.bind("SUPER + ALT + P", hl.dsp.window.pin())

-- Set the tiled algorithm on the current workspace only.
local function setLayout(layout)
  return function()
    local workspace = hl.get_active_workspace()
    if workspace then
      hl.workspace_rule({ workspace = workspace.config_name, layout = layout })
    end
  end
end
hl.bind("SUPER + ALT + 1", setLayout("dwindle"))
hl.bind("SUPER + ALT + 2", setLayout("master"))
hl.bind("SUPER + ALT + 3", setLayout("scrolling"))
hl.bind("SUPER + ALT + 4", setLayout("monocle"))

-- Move focus
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))

-- Swap windows
hl.bind("SUPER + SHIFT + H", hl.dsp.window.swap({ direction = "l" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.swap({ direction = "r" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.swap({ direction = "u" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.swap({ direction = "d" }))

-- Window groups (tabbed windows in one tiled position)
hl.bind("SUPER + G", hl.dsp.group.toggle())
hl.bind("SUPER + TAB", hl.dsp.group.next())
hl.bind("SUPER + SHIFT + TAB", hl.dsp.group.prev())
hl.bind("SUPER + ALT + H", hl.dsp.window.move({ into_group = "left" }))
hl.bind("SUPER + ALT + L", hl.dsp.window.move({ into_group = "right" }))
hl.bind("SUPER + ALT + K", hl.dsp.window.move({ into_group = "up" }))
hl.bind("SUPER + ALT + J", hl.dsp.window.move({ into_group = "down" }))
hl.bind("SUPER + ALT + SHIFT + H", hl.dsp.window.move({ out_of_group = "left" }))
hl.bind("SUPER + ALT + SHIFT + L", hl.dsp.window.move({ out_of_group = "right" }))
hl.bind("SUPER + ALT + SHIFT + K", hl.dsp.window.move({ out_of_group = "up" }))
hl.bind("SUPER + ALT + SHIFT + J", hl.dsp.window.move({ out_of_group = "down" }))

-- Move window between monitors (silent)
hl.bind("SUPER + CTRL + SHIFT + P", hl.dsp.window.move({ monitor = "-1", follow = false }))
hl.bind("SUPER + CTRL + SHIFT + N", hl.dsp.window.move({ monitor = "+1", follow = false }))

-- Resize (repeat)
hl.bind("SUPER + CTRL + H", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + CTRL + L", hl.dsp.window.resize({ x = 10,  y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + CTRL + K", hl.dsp.window.resize({ x = 0,   y = 10, relative = true }), { repeating = true })
hl.bind("SUPER + CTRL + J", hl.dsp.window.resize({ x = 0,   y = -10,relative = true }), { repeating = true })

-- Workspaces
hl.bind("SUPER + 1",  hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + 2",  hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + 3",  hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + 4",  hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + 5",  hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + 6",  hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + 7",  hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + 8",  hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + 9",  hl.dsp.focus({ workspace = 9 }))
hl.bind("SUPER + 0",  hl.dsp.focus({ workspace = 10 }))

-- Move to workspace (follow)
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = 1, follow = true }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = 2, follow = true }))
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = 3, follow = true }))
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = 4, follow = true }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = 5, follow = true }))
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = 6, follow = true }))
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = 7, follow = true }))
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = 8, follow = true }))
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = 9, follow = true }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = 10, follow = true }))

-- Special workspace (scratchpad)
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll workspaces
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse window management
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Move workspace between monitors
hl.bind("SUPER + CTRL + P", hl.dsp.workspace.move({ monitor = "-1" }))
hl.bind("SUPER + CTRL + N", hl.dsp.workspace.move({ monitor = "+1" }))

-- ══════════════════════════════════════════════════════════════
-- 外部程序命令（启动器 / 工具 / bar）
-- ══════════════════════════════════════════════════════════════

-- Application launcher
hl.bind("SUPER + R", hl.dsp.exec_cmd(menu))

-- Bar toggle
hl.bind("SUPER + B", hl.dsp.exec_cmd("quickshell ipc call bar toggle"))

-- Screenshot (region select → annotate with satty → copy)
hl.bind("SUPER + PRINT",      hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | satty -f - --copy-command wl-copy'"))
hl.bind("SUPER + SHIFT + PRINT", hl.dsp.exec_cmd("sh -c 'grim - | wl-copy'"))

-- Clipboard history
hl.bind("SUPER + V", hl.dsp.exec_cmd("clipse"))

-- Lock & exit
hl.bind("SUPER + M",        hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("hyprshutdown"))

-- ══════════════════════════════════════════════════════════════
-- 媒体 / 硬件控制键
-- ══════════════════════════════════════════════════════════════

-- Volume (repeat)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true })

-- Brightness (repeat)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e3 -n2 set 3%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e3 -n2 set 3%-"), { repeating = true })

-- Media controls (locked)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),     { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
