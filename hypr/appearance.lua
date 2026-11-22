-- Hyprland-only palette adapter. nullshell owns and persists the effective appearance mode.
-- Use the shell's effective mode with this configuration's own colours.
-- Window borders use a quieter blue than the shell's interactive accent.
local M = {}

function M.apply(mode)
  if not mode then
    local state = os.getenv("XDG_STATE_HOME")
    if not state or state == "" then state = os.getenv("HOME") .. "/.local/state" end
    local file = io.open(state .. "/nullshell/appearance-mode", "r")
    if file then
      mode = file:read("*a"):match("^%s*(.-)%s*$")
      file:close()
    end
    -- A missing, empty or damaged saved snapshot must still apply a complete palette.
    if mode ~= "dark" and mode ~= "light" then mode = "dark" end
  end
  if mode ~= "dark" and mode ~= "light" then return end

  local dark = mode == "dark"
  local active = dark and "rgba(6487b8ff)" or "rgba(6585afff)"
  local inactive = dark and "rgba(4a535c80)" or "rgba(7c839080)"
  local locked = dark and "rgba(e4bb80ff)" or "rgba(805313ff)"
  hl.config({
    general = {
      ["col.active_border"] = active,
      ["col.inactive_border"] = inactive,
    },
    decoration = {
      shadow = { color = dark and "rgba(00000066)" or "rgba(24272d20)" },
    },
    group = {
      ["col.border_active"] = active,
      ["col.border_inactive"] = inactive,
      ["col.border_locked_active"] = locked,
      ["col.border_locked_inactive"] = dark and "rgba(69717eff)" or "rgba(7c839080)",
      groupbar = {
        text_color = dark and "rgba(f0f1f3ff)" or "rgba(24272dff)",
        ["col.active"] = dark and "rgba(353e4bff)" or "rgba(e0e7f0ff)",
        ["col.inactive"] = dark and "rgba(202328f5)" or "rgba(f4f4f5fa)",
        ["col.locked_active"] = dark and "rgba(51432dff)" or "rgba(f0e3cdff)",
        ["col.locked_inactive"] = dark and "rgba(292d33ff)" or "rgba(e6e8ebff)",
      },
    },
  })
end

return M
