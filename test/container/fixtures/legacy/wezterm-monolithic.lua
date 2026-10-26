-- A single-file WezTerm config from before the common/local split: it loads
-- no common file, so uninstall-legacy must move it unchanged. Like the old
-- repo version it has a top-level servers registry before "return config",
-- the anchor install would insert a block at, so only the recorded unmanaged
-- state keeps install away from it.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local home = wezterm.home_dir
local sep  = package.config:sub(1,1)

local servers = {
  { name = 'box', host = '10.0.0.5', user = 'me', key = 'box.pem' },
}

config.font_size = 11
config.color_scheme = 'Builtin Dark'
config.launch_menu = {}
for _, s in ipairs(servers) do
  table.insert(config.launch_menu, {
    label = 'SSH ' .. s.name,
    args  = { 'ssh', '-i', home .. sep .. s.key, s.user .. '@' .. s.host },
  })
end

return config
