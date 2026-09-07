require("settings")
require("binds")
require("rules")
require("startup")

-- `monitors.lua` is generated locally by hyprmoncfg and intentionally not
-- deployed.  A fresh machine must still be able to start Hyprland before the
-- daemon has produced that file.
local monitorsLoaded = pcall(require, "monitors")
if not monitorsLoaded then
  hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.0,
  })
end
