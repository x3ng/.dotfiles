local terminal = "kitty"

-- A visible special workspace takes precedence over the monitor's regular workspace.
local function activeWorkspace()
  return hl.get_active_special_workspace() or hl.get_active_workspace()
end

-- ══════════════════════════════════════════════════════════════
-- Hyprland 原生快捷键（窗口/工作区/布局管理）
-- ══════════════════════════════════════════════════════════════

-- Launch & window controls
-- T = terminal.
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal))
-- Close mirrors SUPER + Q (the launcher): same key with Shift, like SUPER + F / SUPER + SHIFT + F.
-- The C key was avoided on purpose: SUPER + CTRL/SHIFT + C collide with Ctrl+C and Ctrl+Shift+C.
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
hl.bind("SUPER + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.pseudo({ action = "toggle" }))
-- Pin toggles visibility across workspaces on this monitor; the window must be floating.
hl.bind("SUPER + ALT + P", hl.dsp.window.pin())

-- Set the tiled algorithm on the current workspace only.
local function setLayout(layout)
  return function()
    local workspace = activeWorkspace()
    if workspace then
      hl.workspace_rule({ workspace = workspace.config_name, layout = layout })
      -- Quickshell reads the resulting state rather than trusting the requested layout.
      hl.dispatch(hl.dsp.event("workspace-layout"))
    end
  end
end
-- Move focus
local function layoutAction(actions)
  return function()
    local workspace = activeWorkspace()
    local window = hl.get_active_window()
    if not workspace or not window or window.floating then return end
    local message = actions[workspace.tiled_layout]
    if message then hl.dispatch(hl.dsp.layout(message)) end
  end
end

local function focusDirection(direction, next)
  return function()
    local workspace = activeWorkspace()
    local window = hl.get_active_window()
    if workspace and workspace.tiled_layout == "monocle" and window and not window.floating then
      hl.dispatch(hl.dsp.layout(next and "cyclenext" or "cycleprev"))
    elseif workspace and workspace.tiled_layout == "scrolling" and window and not window.floating
        and (direction == "l" or direction == "r") then
      hl.dispatch(hl.dsp.layout("focus " .. direction))
    else
      hl.dispatch(hl.dsp.focus({ direction = direction }))
    end
  end
end
hl.bind("SUPER + H", focusDirection("l", false))
hl.bind("SUPER + L", focusDirection("r", true))
hl.bind("SUPER + K", focusDirection("u", false))
hl.bind("SUPER + J", focusDirection("d", true))

-- Workspace window cycling is separate from Super+Tab's group tabs.
local function cycleWindow(next)
  return function()
    local workspace = activeWorkspace()
    local window = hl.get_active_window()
    if workspace and workspace.tiled_layout == "monocle" and window and not window.floating then
      hl.dispatch(hl.dsp.layout(next and "cyclenext" or "cycleprev"))
    else
      hl.dispatch(hl.dsp.window.cycle_next({ next = next }))
    end
  end
end
hl.bind("SUPER + N", cycleWindow(true))
hl.bind("SUPER + P", cycleWindow(false))

-- R = reshape: change orientation; Enter focuses the master, Shift+Enter promotes to master.
hl.bind("SUPER + R", layoutAction({ dwindle = "togglesplit", master = "orientationnext" }))
hl.bind("SUPER + Return", layoutAction({ master = "focusmaster previous" }))
hl.bind("SUPER + SHIFT + Return", layoutAction({ master = "swapwithmaster master" }))
-- W = width preset; Shift reverses the cycle. Only scrolling has column presets.
hl.bind("SUPER + W", layoutAction({ scrolling = "colresize +conf" }))
hl.bind("SUPER + SHIFT + W", layoutAction({ scrolling = "colresize -conf" }))

-- Direct layout selection.
hl.bind("SUPER + ALT + D", setLayout("dwindle"))
hl.bind("SUPER + ALT + M", setLayout("master"))
hl.bind("SUPER + ALT + S", setLayout("scrolling"))
hl.bind("SUPER + ALT + O", setLayout("monocle"))

-- D = Down, E = East; Shift reverses the next dwindle split direction.
hl.bind("SUPER + D", layoutAction({ dwindle = "preselect d" }))
hl.bind("SUPER + SHIFT + D", layoutAction({ dwindle = "preselect u" }))
hl.bind("SUPER + E", layoutAction({ dwindle = "preselect r" }))
hl.bind("SUPER + SHIFT + E", layoutAction({ dwindle = "preselect l" }))
hl.bind("SUPER + ALT + Space", layoutAction({ dwindle = "preselect none" }))

-- Scrolling columns: brackets move columns, X combines/separates, O extracts/centers.
-- 0.56.2 consume pulls the next column's FIRST window; expel extracts THIS column's
-- LAST window. promote extracts the FOCUSED window.
hl.bind("SUPER + bracketleft", layoutAction({ scrolling = "swapcol l" }))
hl.bind("SUPER + bracketright", layoutAction({ scrolling = "swapcol r" }))
hl.bind("SUPER + X", layoutAction({ scrolling = "consume" }))
hl.bind("SUPER + SHIFT + X", layoutAction({ scrolling = "expel" }))
hl.bind("SUPER + O", layoutAction({ scrolling = "promote" }))
hl.bind("SUPER + SHIFT + O", layoutAction({ scrolling = "center" }))

-- Shift+directions changes position: tiled swap, or 20px floating movement.
-- Monocle has no spatial neighbors: do not accidentally swap across monitors.
local function moveDirection(direction, x, y)
  return function()
    local window = hl.get_active_window()
    if not window then return end
    if window.floating then
      hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = true }))
    else
      local workspace = activeWorkspace()
      if workspace and workspace.tiled_layout == "monocle" then return end
      hl.dispatch(hl.dsp.window.swap({ direction = direction }))
    end
  end
end
hl.bind("SUPER + SHIFT + H", moveDirection("l", -20, 0))
hl.bind("SUPER + SHIFT + L", moveDirection("r", 20, 0))
hl.bind("SUPER + SHIFT + K", moveDirection("u", 0, -20))
hl.bind("SUPER + SHIFT + J", moveDirection("d", 0, 20))

-- Groups: G toggles the whole group; Alt+G takes only the current tab out.
hl.bind("SUPER + G", hl.dsp.group.toggle())
hl.bind("SUPER + ALT + G", hl.dsp.window.move({ out_of_group = "right" }))
hl.bind("SUPER + TAB", hl.dsp.group.next())
hl.bind("SUPER + SHIFT + TAB", hl.dsp.group.prev())
for _, direction in ipairs({ { "H", "left" }, { "J", "down" }, { "K", "up" }, { "L", "right" } }) do
  hl.bind("SUPER + ALT + " .. direction[1], hl.dsp.window.move({ into_group = direction[2] }))
end

-- Resize (repeat)
local function resizeWidth(direction)
  return function()
    local window = hl.get_active_window()
    if not window then return end
    local workspace = activeWorkspace()
    if not window.floating and workspace and workspace.tiled_layout == "scrolling" then
      -- Column resizing refits the viewport, so the rightmost column can grow too.
      hl.dispatch(hl.dsp.layout(direction > 0 and "colresize +0.05" or "colresize -0.05"))
    else
      hl.dispatch(hl.dsp.window.resize({ x = direction * 10, y = 0, relative = true }))
    end
  end
end
hl.bind("SUPER + CTRL + H", resizeWidth(-1), { repeating = true })
hl.bind("SUPER + CTRL + L", resizeWidth(1), { repeating = true })
hl.bind("SUPER + CTRL + K", hl.dsp.window.resize({ x = 0,   y = 10, relative = true }), { repeating = true })
hl.bind("SUPER + CTRL + J", hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })

-- Numbers: focus; Shift = bring the window with you; Ctrl = send it and stay.
for workspace = 1, 10 do
  local key = tostring(workspace % 10)
  hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = workspace }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace, follow = true }))
  hl.bind("SUPER + CTRL + " .. key, hl.dsp.window.move({ workspace = workspace, follow = false }))
end
-- B = back to the last visited workspace; U/I are adjacent previous/next keys.
hl.bind("SUPER + B", hl.dsp.focus({ workspace = "previous" }))
hl.bind("SUPER + U", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + I", hl.dsp.focus({ workspace = "e+1" }))

-- Special workspace (scratchpad)
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll workspaces
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse window management
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Monitors by index: focus; Shift sends the window; Ctrl carries the workspace.
for _, monitor in ipairs({ { "comma", "-1" }, { "period", "+1" } }) do
  local key, target = monitor[1], monitor[2]
  hl.bind("SUPER + " .. key, hl.dsp.focus({ monitor = target }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ monitor = target, follow = false }))
  hl.bind("SUPER + CTRL + " .. key, hl.dsp.workspace.move({ monitor = target }))
end

-- ══════════════════════════════════════════════════════════════
-- 外部程序命令（启动器 / 工具）
-- ══════════════════════════════════════════════════════════════

-- Application launcher (Q); Super+T launches the terminal.
hl.bind("SUPER + Q", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"))

-- Screenshot (region select → annotate with satty → copy)
local screenshotArea = "sh -c 'geometry=$(slurp) || exit 0; [ -n \"$geometry\" ] || exit 0; grim -g \"$geometry\" - | satty -f - --copy-command wl-copy'"
local screenshotAll = "sh -c 'grim - | wl-copy'"
-- A = area; Shift+A = all.
hl.bind("SUPER + A", hl.dsp.exec_cmd(screenshotArea))
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd(screenshotAll))

-- Clipboard history
hl.bind("SUPER + V", hl.dsp.exec_cmd(terminal .. " --class clipse -e clipse"))

-- Lock & exit
hl.bind("SUPER + M",        hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("hyprshutdown"))

-- ══════════════════════════════════════════════════════════════
-- 媒体 / 硬件控制键
-- ══════════════════════════════════════════════════════════════

-- Volume (repeat)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- Brightness (repeat)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e3 -n2 set 3%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e3 -n2 set 3%-"), { repeating = true })

-- Media controls (locked)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),     { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
