-- Build-time check after `Lazy! sync` (build/editor.sh): fails nvim (cquit)
-- when a lazy.nvim plugin is not installed, builds the treesitter parsers
-- lua/init.lua asks for, then waits for coc to install g:coc_global_extensions.
-- What did not install is listed in build-checks/ts-missing.txt and
-- build-checks/coc-missing.txt, and editor.sh fails on either.
local checks = "/opt/dotfiles-test/build-checks"

local missing = {}
for _, p in ipairs(require("lazy").plugins()) do
    if not (p._ and p._.installed) then
        missing[#missing + 1] = p.name
    end
end
if #missing > 0 then
    io.stderr:write("nvim plugins not installed: " .. table.concat(missing, " ") .. "\n")
    vim.cmd("cquit 1")
end

local init = table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lua/init.lua"), "\n")
local list = init:match("local ts_parsers = (%b{})")
if not list then
    io.stderr:write("ts_parsers not found in lua/init.lua\n")
    vim.cmd("cquit 1")
end
local ts = require("nvim-treesitter")
local available = {}
for _, lang in ipairs(ts.get_available()) do
    available[lang] = true
end
local parsers, unsupported = {}, {}
for _, lang in ipairs(assert(load("return " .. list))()) do
    if available[lang] then
        parsers[#parsers + 1] = lang
    else
        unsupported[#unsupported + 1] = lang
    end
end
if #unsupported > 0 then
    io.stderr:write("nvim-treesitter has no parser for: " .. table.concat(unsupported, " ") .. "\n")
end

local function not_built()
    local have, left = {}, {}
    for _, lang in ipairs(ts.get_installed()) do
        have[lang] = true
    end
    for _, lang in ipairs(parsers) do
        if not have[lang] then
            left[#left + 1] = lang
        end
    end
    return left
end

-- lua/init.lua started the same install in this nvim, and the `Lazy! sync`
-- nvim quit with builds still running that outlive it. Builds of one parser
-- in two places collide in ~/.cache/nvim/tree-sitter-<lang>-tmp; the second
-- pass, after both have drained, retries what they broke.
ts.install(parsers):wait(1800000)
missing = not_built()
if #missing > 0 then
    ts.install(missing):wait(1800000)
    missing = not_built()
end
vim.fn.writefile(missing, checks .. "/ts-missing.txt")

-- coc starts its service on VimEnter, which comes after this -c script, and
-- then installs the global extensions that are not in its data home.
local function coc_missing(home)
    local ok, pkg = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(home .. "/extensions/package.json"), "\n"))
    end)
    local deps = ok and type(pkg) == "table" and type(pkg.dependencies) == "table" and pkg.dependencies or {}
    local left = {}
    for _, name in ipairs(vim.g.coc_global_extensions or {}) do
        if not (deps[name] and vim.uv.fs_stat(home .. "/extensions/node_modules/" .. name .. "/package.json")) then
            left[#left + 1] = name
        end
    end
    return left
end

vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        local ok, err = pcall(function()
            local home = vim.fn["coc#util#get_data_home"]()
            vim.wait(600000, function()
                return #coc_missing(home) == 0
            end, 1000)
            vim.fn.writefile(coc_missing(home), checks .. "/coc-missing.txt")
        end)
        if not ok then
            io.stderr:write("coc extensions: " .. tostring(err) .. "\n")
            vim.cmd("cquit 1")
        end
        vim.cmd("qa!")
    end,
})
