-- Catch-all stand-in for WezTerm's `wezterm` module (A21), loaded by load.lua
-- through package.path. Any unknown field is a callable, indexable proxy, so
-- config code runs without WezTerm; numeric keys stay nil so ipairs() ends.
-- config_dir, home_dir and target_triple are real strings set by the loader.
local function proxy(name)
    local function same()
        return proxy(name)
    end
    local function never()
        return false
    end
    return setmetatable({}, {
        __index = function(t, key)
            if type(key) ~= "string" then
                return nil
            end
            local p = proxy(name .. "." .. key)
            rawset(t, key, p)
            return p
        end,
        __call = function()
            return proxy(name .. "()")
        end,
        __concat = function(a, b)
            return tostring(a) .. tostring(b)
        end,
        __tostring = function()
            return name
        end,
        __add = same, __sub = same, __mul = same, __div = same, __unm = same,
        __lt = never, __le = never,
    })
end

local wezterm = proxy("wezterm")
wezterm.config_dir = "/nonexistent"
wezterm.home_dir = "/nonexistent"
wezterm.target_triple = "x86_64-unknown-linux-gnu"
wezterm.watched = {}
wezterm.events = {}

function wezterm.config_builder()
    return {}
end

function wezterm.add_to_config_reload_watch_list(path)
    wezterm.watched[#wezterm.watched + 1] = path
end

function wezterm.on(event, handler)
    wezterm.events[event] = handler
end

return wezterm
