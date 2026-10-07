require("environment")
require("compositor")
require("binds")
require("rules")
require("apps")
require("startup")

-- Optional on first login; hyprmoncfg creates this file after Hyprland starts.
-- Resolve runtime state separately because the main config is a symlink.
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local monitor_config = config_home .. "/hypr/monitors.lua"
local monitor_file = io.open(monitor_config, "r")
if monitor_file then
  monitor_file:close()
  dofile(monitor_config)
end

-- Follow darkman's own cached mode on startup and config reload.
require("appearance").apply()
