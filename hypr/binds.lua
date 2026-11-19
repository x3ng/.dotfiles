-- Two direction vocabularies, one meaning each — never make the same action
-- reachable from both, because that is how keys start multiplying:
--
--   HJKL = geometry: two dimensions between neighbours.
--          bare = focus · SHIFT = move/swap · CTRL = resize · ALT = into a group.
--          Four layers is the limit. New geometry work belongs inside a layout-aware
--          dispatcher on these keys, never on a fresh letter.
--
--   FBNP = sequence: one dimension, forward/back through an ordered line.
--          A sequence has only two directions, so one modifier layer carries two
--          objects (N/P and F/B). bare = jump · SHIFT = move the object · ALT = container level.
--
-- Neither geometry nor sequence (a plain toggle) gets one bare single key.

local terminal = "kitty"
local workspaces = require("workspaces")

-- A visible special workspace takes precedence over the monitor's regular workspace.
local function activeWorkspace()
  return workspaces.active()
end

-- ══════════════════════════════════════════════════════════════
-- Hyprland 原生快捷键（窗口/工作区/布局管理）
-- ══════════════════════════════════════════════════════════════

-- Launch & window controls
-- T = terminal.
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal))
-- Close mirrors SUPER + Q (the launcher): same key with Shift, like SUPER + Z / SUPER + SHIFT + Z.
-- Keep Ctrl+C and Ctrl+Shift+C available to applications.
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
hl.bind("SUPER + Space", hl.dsp.window.float({ action = "toggle" }))
-- Fullscreen sits on Z because F now steps through workspaces on the sequence axis.
hl.bind("SUPER + Z", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + SHIFT + Z", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.pseudo({ action = "toggle" }))
-- Pin toggles visibility across workspaces on this monitor; the window must be floating.
-- Shift keeps the P family together: P = previous window, Alt+P = previous group tab.
hl.bind("SUPER + SHIFT + P", hl.dsp.window.pin())

-- Set the tiled algorithm on the current workspace only.
local function setLayout(layout)
  return function()
    workspaces.set_layout(activeWorkspace(), layout)
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

-- Sequence axis: N/P visit tiled and floating windows, including inactive
-- monocle tiles. Group tabs retain their separate Alt+N/P bindings.
hl.bind("SUPER + N", function() workspaces.cycle_window(true) end)
hl.bind("SUPER + P", function() workspaces.cycle_window(false) end)

-- Tab is deliberately left unbound for window cycling: cyclenext only filters by
-- tiled/floating, so "rotate the windows stacked here" has no native expression
-- and is not worth a geometric side channel. N/P is the universal tour.

-- Sway-style adjustment mode: release Super, then keep both hands on the keyboard.
-- Remember only the address; never keep window userdata after a window closes.
local floatAdjustmentTarget
local function leaveFloatAdjustment()
  floatAdjustmentTarget = nil
  hl.dispatch(hl.dsp.submap("reset"))
end

local function adjustFloat(x, y, resize)
  return function()
    local window = hl.get_active_window()
    -- Mouse focus changes or closing the target must not move another window.
    if not window or not window.floating or window.address ~= floatAdjustmentTarget then
      leaveFloatAdjustment()
      return
    end
    local options = { x = x, y = y, relative = true }
    hl.dispatch(resize and hl.dsp.window.resize(options) or hl.dsp.window.move(options))
  end
end

hl.define_submap("float-adjust", function()
  for _, direction in ipairs({
    { key = "H", x = -1, y = 0 },
    { key = "J", x = 0, y = 1 },
    { key = "K", x = 0, y = -1 },
    { key = "L", x = 1, y = 0 },
  }) do
    hl.bind(direction.key, adjustFloat(direction.x * 20, direction.y * 20, false), { repeating = true })
    -- Keep the existing Ctrl+HJKL resize semantics: K grows height, J shrinks it.
    hl.bind("CTRL + " .. direction.key, adjustFloat(direction.x * 10, -direction.y * 10, true), { repeating = true })
  end
  hl.bind("Return", leaveFloatAdjustment)
  hl.bind("Escape", leaveFloatAdjustment)
  -- Unrelated typing must not reach the application while adjusting its window.
  hl.bind("catchall", function() end)
end)

-- R = reshape: floating adjustment, or change the tiled layout's orientation.
-- Enter focuses the master, Shift+Enter promotes to master.
local reshapeLayout = layoutAction({ dwindle = "togglesplit", master = "orientationnext" })
hl.bind("SUPER + R", function()
  local window = hl.get_active_window()
  if not window or not window.floating then
    reshapeLayout()
    return
  end
  floatAdjustmentTarget = window.address
  hl.dispatch(hl.dsp.submap("float-adjust"))
  hl.notification.create({
    text = "Float: H/J/K/L move | Ctrl resize | Enter/Esc exit",
    timeout = 6000,
  })
end)
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

-- Scrolling columns form a one-dimensional line, so column order is a sequence
-- operation: Shift+F/B move the column forward/back. X, O and W stay on their own
-- keys because they are verbs without a direction.
-- Scrolling consume pulls the next column's FIRST window; expel extracts THIS column's
-- LAST window. promote extracts the FOCUSED window.
hl.bind("SUPER + SHIFT + F", layoutAction({ scrolling = "swapcol r" }))
hl.bind("SUPER + SHIFT + B", layoutAction({ scrolling = "swapcol l" }))
hl.bind("SUPER + X", layoutAction({ scrolling = "consume" }))
hl.bind("SUPER + SHIFT + X", layoutAction({ scrolling = "expel" }))
hl.bind("SUPER + O", layoutAction({ scrolling = "promote" }))
hl.bind("SUPER + SHIFT + O", layoutAction({ scrolling = "center" }))

-- Repeat pixel movement for floats. Tiled swaps fire once per keypress.
local function bindMove(key, direction, x, y)
  local chord = "SUPER + SHIFT + " .. key
  hl.bind(chord, function()
    local window = hl.get_active_window()
    if not window or window.floating then return end
    local workspace = activeWorkspace()
    if workspace and workspace.tiled_layout == "monocle" then return end
    hl.dispatch(hl.dsp.window.swap({ direction = direction }))
  end)
  hl.bind(chord, function()
    local window = hl.get_active_window()
    if window and window.floating then
      hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = true }))
    end
  end, { repeating = true })
end
bindMove("H", "l", -20, 0)
bindMove("L", "r", 20, 0)
bindMove("K", "u", 0, -20)
bindMove("J", "d", 0, 20)

-- Groups: G toggles the whole group; Alt+G takes only the current tab out.
hl.bind("SUPER + G", hl.dsp.group.toggle())
hl.bind("SUPER + ALT + G", hl.dsp.window.move({ out_of_group = "right" }))
-- Tabs are a sequence too, and Alt is the container level: the same grammar as
-- Alt+HJKL for moving a window into a group. Tabs need their own keys because
-- cycle_next stops at group members instead of walking through them.
hl.bind("SUPER + ALT + N", hl.dsp.group.next())
hl.bind("SUPER + ALT + P", hl.dsp.group.prev())
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
-- Sequence axis, container level: F/B step through existing workspaces.
-- History is a stack rather than a sequence, so going back keeps its own key.
hl.bind("SUPER + F", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + B", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + grave", hl.dsp.focus({ workspace = "previous" }))

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
hl.bind("SUPER + Q", hl.dsp.exec_cmd("nullshell ipc call launcher toggle"))

-- Screenshot (region select → annotate with satty → copy)
local screenshotArea = "sh -c 'geometry=$(slurp) || exit 0; [ -n \"$geometry\" ] || exit 0; grim -g \"$geometry\" - | satty -f - --copy-command wl-copy'"
local screenshotAll = "sh -c 'grim - | wl-copy'"
-- A = area; Shift+A = all.
hl.bind("SUPER + A", hl.dsp.exec_cmd(screenshotArea))
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd(screenshotAll))

-- Clipboard history
-- Use a compact font and explicit terminal dimensions for the floating picker.
hl.bind("SUPER + V", hl.dsp.exec_cmd(terminal .. " --class clipse -o font_size=11 -o initial_window_width=100c -o initial_window_height=30c -e clipse"))

-- Lock and end the UWSM-managed session
hl.bind("SUPER + M",        hl.dsp.exec_cmd("nullshell lock"))
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("uwsm stop"))

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
