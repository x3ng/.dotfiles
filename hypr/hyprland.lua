require("environment")
require("compositor")
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
