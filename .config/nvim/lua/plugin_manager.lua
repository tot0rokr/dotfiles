-- Neovim's plugins, managed by lazy.nvim: the list shared with Vim
-- (~/.vim/plugins.vim, written for vim-plug) plus the Neovim-only specs in
-- lua/plugins/.
local M = {}

local root = vim.fn.stdpath("data") .. "/lazy"
local shared_specs = {}

-- The vim-plug options ~/.vim/plugins.vim may use, and their lazy.nvim keys
local lazy_keys = {
    on = "cmd",
    ["for"] = "ft",
    ["do"] = "build",
    branch = "branch",
}

local function add_shared(repo, opts)
    local spec = { repo }
    for key, value in pairs(opts or {}) do
        if not lazy_keys[key] then
            error(string.format("~/.vim/plugins.vim: Plug '%s' uses unsupported option '%s'", repo, key))
        end
        spec[lazy_keys[key]] = value
    end
    table.insert(shared_specs, spec)
end

-- Read ~/.vim/plugins.vim through a :Plug that only records each spec, and
-- set g:plugin_dirs for PluginInstalled() in ~/.vim/common.vim.
function M.read_shared_list()
    vim.api.nvim_create_user_command("Plug", function(cmd)
        add_shared(unpack(vim.fn.eval("[" .. cmd.args .. "]")))
    end, { nargs = "+", bar = true })
    vim.cmd.source("~/.vim/plugins.vim")
    vim.api.nvim_del_user_command("Plug")

    local dirs = {}
    for _, spec in ipairs(shared_specs) do
        local name = spec[1]:match("[^/]+$")
        dirs[name] = root .. "/" .. name
    end
    vim.g.plugin_dirs = dirs
end

function M.setup()
    local lazypath = root .. "/lazy.nvim"
    if not vim.uv.fs_stat(lazypath) then
        local out = vim.fn.system({
            "git", "clone", "--filter=blob:none", "--branch=stable",
            "https://github.com/folke/lazy.nvim.git", lazypath,
        })
        if vim.v.shell_error ~= 0 then
            error("Failed to clone lazy.nvim:\n" .. out)
        end
    end
    vim.opt.rtp:prepend(lazypath)

    require("lazy").setup({
        spec = { shared_specs, { import = "plugins" } },
        -- a spec with `dev = true` loads ~/<plugin name> when that checkout
        -- exists on this host, and the git clone otherwise
        dev = { path = "~", fallback = true },
        performance = {
            rtp = {
                -- lazy.nvim resets 'runtimepath'; keep ~/.vim and the fzf
                -- checkout install_fzf_user (.bashrc.common) keeps in ~/.fzf
                paths = {
                    vim.fn.expand("~/.vim"),
                    vim.fn.expand("~/.fzf"),
                    vim.fn.expand("~/.vim/after"),
                },
            },
        },
    })
end

return M
