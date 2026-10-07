-- Hyprland-only palette adapter. Mode and scheduling belong to darkman.
local M = {}

function M.apply(mode)
  if not mode then
    local cache = os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")
    local file = io.open(cache .. "/darkman/mode.txt", "r")
    if file then
      mode = file:read("*a"):match("^%s*(.-)%s*$")
      file:close()
    else
      mode = "dark"
    end
  end
  if mode ~= "dark" and mode ~= "light" then return end

  local dark = mode == "dark"
  local active = dark and "rgba(649486ff)" or "rgba(67b99aff)"
  local inactive = dark and "rgba(48505880)" or "rgba(747e8a80)"
  local locked = dark and "rgba(e4bb80ff)" or "rgba(805313ff)"
  hl.config({
    general = {
      ["col.active_border"] = active,
      ["col.inactive_border"] = inactive,
    },
    decoration = {
      shadow = { color = dark and "rgba(00000080)" or "rgba(20262d26)" },
    },
    group = {
      ["col.border_active"] = active,
      ["col.border_inactive"] = inactive,
      ["col.border_locked_active"] = locked,
      ["col.border_locked_inactive"] = dark and "rgba(606b78ff)" or "rgba(747e8a80)",
      groupbar = {
        text_color = dark and "rgba(edf0f3ff)" or "rgba(20262dff)",
        ["col.active"] = dark and "rgba(263a35ff)" or "rgba(bcded2ff)",
        ["col.inactive"] = dark and "rgba(1b1d20f5)" or "rgba(f0f1f3fa)",
        ["col.locked_active"] = dark and "rgba(51432dff)" or "rgba(f0e3cdff)",
        ["col.locked_inactive"] = dark and "rgba(292c30ff)" or "rgba(e2e5e9ff)",
      },
    },
  })
end

return M
