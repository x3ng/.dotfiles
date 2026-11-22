local workspaces = require("workspaces")
local workspaceLayouts = workspaces.snapshot_layouts()

require("environment")
require("compositor")

-- Restore before explicit workspace rules so configured layouts take precedence.
workspaces.restore_layouts(workspaceLayouts)

require("binds")
require("rules")
require("apps")
require("startup")

require("monitor")

-- Follow nullshell's saved mode on startup and config reload.
require("appearance").apply()
