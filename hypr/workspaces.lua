-- Shared workspace actions for key bindings and Quickshell's explicit targets.
local M = {}
local layouts = { dwindle = true, master = true, scrolling = true, monocle = true }

function M.is_layout(layout)
  return layouts[layout] == true
end

function M.active()
  return hl.get_active_special_workspace() or hl.get_active_workspace()
end

function M.set_layout(workspace, layout)
  if not M.is_layout(layout) then return false, "Unknown workspace layout" end
  local name = workspace and workspace.addressable_name
  if type(name) ~= "string" or name == "" then return false, "Workspace no longer exists" end

  -- Workspace rules refresh persistent monitor placement too. Preserve manual
  -- moves until reload, when hyprmoncfg's configured assignments take precedence.
  for _, existing in ipairs(hl.get_workspaces()) do
    local monitor = existing.monitor
    if existing.is_persistent and monitor then
      hl.workspace_rule({ workspace = existing.addressable_name, monitor = monitor.name })
    end
  end
  hl.workspace_rule({ workspace = name, layout = layout })
  return true
end

function M.cycle_window(next)
  local workspace = M.active()
  if not workspace or workspace.tiled_layout ~= "monocle" then
    hl.dispatch(hl.dsp.window.cycle_next({ next = next }))
    return
  end

  -- Generic cycle_next skips inactive monocle tiles; the layout's own cycle
  -- skips floats. Enumerate native windows only for this layout, in their
  -- compositor order. Hidden group tabs stay on the separate group bindings.
  local current = hl.get_active_window()
  local windows, index = {}, nil
  for _, window in ipairs(workspace:get_windows()) do
    if window.mapped and not window.hidden and (not window.floating or window.accepts_input) then
      windows[#windows + 1] = window
      if current and window.address == current.address then index = #windows end
    end
  end
  if #windows == 0 then return end
  index = index or (next and 0 or 1)
  local step = next and 1 or -1
  for offset = 1, #windows do
    local target = windows[(index - 1 + step * offset) % #windows + 1]
    hl.dispatch(hl.dsp.focus({ window = target }))
    -- no_focus/modal/lock rules can refuse focus; do not get stuck on that entry.
    local focused = hl.get_active_window()
    if focused and focused.address == target.address then return end
  end
end

return M
