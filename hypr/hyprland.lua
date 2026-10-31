-- Reload clears runtime workspace rules before evaluating this file, but the
-- live layouts survive until Hyprland's deferred layout refresh. Snapshot them
-- now so monitor-profile reloads do not reset every workspace to dwindle.
-- Store plain strings, never workspace userdata across monitor reconfiguration.
local workspaceLayouts = {}
local workspaces = require("workspaces")
for _, workspace in ipairs(hl.get_workspaces()) do
  local name, layout = workspace.addressable_name, workspace.tiled_layout
  if type(name) == "string" and name ~= "" and workspaces.is_layout(layout) then
    workspaceLayouts[#workspaceLayouts + 1] = { workspace = name, layout = layout }
  end
end

require("environment")
require("compositor")

-- Restore before explicit workspace rules: configured layouts take precedence,
-- while general.layout remains the default for workspaces without a rule.
-- Hyprland merges these layout-only rules with other fields for the selector.
for _, rule in ipairs(workspaceLayouts) do
  hl.workspace_rule(rule)
end

require("binds")
require("rules")
require("apps")
require("startup")

-- Apply the fallback first, then optional user monitor rules.
-- hyprmoncfg's generated file loads last below.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})
if package.searchpath("monitors", package.path) then
  require("monitors")
end

-- Follow Quickshell's saved mode on startup and config reload.
require("appearance").apply()

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
