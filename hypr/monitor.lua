-- Native fallback for login, rollback and monitor combinations without a match.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})

-- Optional confirmed-layout provider. Hyprland reads it without a running shell.
-- Remove this section to use only the native rules above.
local config = os.getenv("XDG_CONFIG_HOME")
if not config or config == "" then config = os.getenv("HOME") .. "/.config" end
_G.nullshellDisplayStore = config .. "/nullshell/hyprland-displays.lua"
local restore = loadfile(_G.nullshellDisplayStore)
if restore then restore() end
