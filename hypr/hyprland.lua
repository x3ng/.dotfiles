-- Reload clears runtime workspace rules before evaluating this file, but the
-- live layouts survive until Hyprland's deferred layout refresh. Snapshot them
-- now so monitor-profile reloads do not reset every workspace to dwindle.
-- Store plain strings, never workspace userdata across monitor reconfiguration.
local workspaceLayouts = {}
local builtinLayouts = { dwindle = true, master = true, scrolling = true, monocle = true }
for _, workspace in ipairs(hl.get_workspaces()) do
  local name, layout = workspace.config_name, workspace.tiled_layout
  if type(name) == "string" and name ~= "" and builtinLayouts[layout] then
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

-- hyprmoncfg generates monitors.lua, then reloads Hyprland to apply it.
-- Its static include check needs a literal argument; dofile(variable) is not recognized.
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
