-- Loads an installed wezterm.lua against the stub module (A21) and checks
-- that it returns the config table, calls common.lua's apply() exactly once
-- and watches common.lua for reloads.
--   lua5.4 load.lua STUB_DIR CONFIG_DIR HOME_DIR WEZTERM_LUA
local stub_dir, config_dir, home_dir, entry = ...
assert(entry, "usage: load.lua STUB_DIR CONFIG_DIR HOME_DIR WEZTERM_LUA")
package.path = stub_dir .. "/?.lua;" .. package.path

local wezterm = require("wezterm")
wezterm.config_dir = config_dir
wezterm.home_dir = home_dir

local applied = 0
local real_dofile = dofile
-- Counts apply() calls of every module the config loads with dofile().
dofile = function(path)
    local module = real_dofile(path)
    if type(module) == "table" and type(module.apply) == "function" then
        local apply = module.apply
        module.apply = function(...)
            applied = applied + 1
            return apply(...)
        end
    end
    return module
end

local config = real_dofile(entry)
assert(type(config) == "table", "wezterm.lua did not return the config table")
assert(applied == 1, "common.lua apply() ran " .. applied .. " times, want 1")
local watched = false
for _, path in ipairs(wezterm.watched) do
    if path == config_dir .. "/common.lua" then
        watched = true
    end
end
assert(watched, "common.lua is not on the reload watch list")
print("wezterm.lua loads: apply() ran once, common.lua watched")
