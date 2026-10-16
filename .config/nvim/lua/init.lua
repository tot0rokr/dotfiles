-- This module contains a number of default definitions
local rainbow_delimiters = require 'rainbow-delimiters'

---@type rainbow_delimiters.config
vim.g.rainbow_delimiters = {
    strategy = {
        [''] = rainbow_delimiters.strategy['global'],
        vim = rainbow_delimiters.strategy['local'],
    },
    query = {
        [''] = 'rainbow-delimiters',
        lua = 'rainbow-blocks',
    },
    priority = {
        [''] = 110,
        lua = 210,
    },
    highlight = {
        'RainbowDelimiterRed',
        'RainbowDelimiterYellow',
        'RainbowDelimiterBlue',
        'RainbowDelimiterOrange',
        'RainbowDelimiterGreen',
        'RainbowDelimiterViolet',
        'RainbowDelimiterCyan',
    },
}

-- Load the ibl.hooks module
local hooks = require "ibl.hooks"

-- create the highlight groups in the highlight setup hook, so they are reset
-- every time the colorscheme changes

hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
    local colors = {
        RainbowDelimiterRed = "#E06C75",
        RainbowDelimiterYellow = "#E5C07B",
        RainbowDelimiterBlue = "#61AFEF",
        RainbowDelimiterOrange = "#D19A66",
        RainbowDelimiterGreen = "#98C379",
        RainbowDelimiterViolet = "#C678DD",
        RainbowDelimiterCyan = "#56B6C2",
    }
    for group, color in pairs(colors) do
        vim.api.nvim_set_hl(0, group, { fg = color })
    end
end)

-- vim.g.rainbow_delimiters = { highlight = highlight }
-- require("ibl").setup { scope = { highlight = highlight } }
-- Setup ibl with scope highlight
require("ibl").setup { scope = { highlight = vim.g.rainbow_delimiters.highlight } }

-- Register scope highlight hook
hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)


-- notify
require("notify").setup({
    background_colour = "#000000",
})

-- noice
require("noice").setup({
    lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
        },
    },
    -- hlslens already shows [index/total] next to the matches
    messages = { view_search = false },
    -- you can enable a preset for easier configuration
    presets = {
        bottom_search = true, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = false, -- add a border to hover docs and signature help
    },
})

-- nvim-Treesitter (main branch API)
local ts_parsers = {
    "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline",
    "python", "bash", "asm", "cpp", "cmake", "csv", "devicetree", "dart",
    "dockerfile", "diff", "git_config", "git_rebase", "gitcommit", "gitignore",
    "html", "htmldjango", "http", "kconfig", "nasm", "nginx", "ninja",
    "passwd", "pem", "rst", "tmux", "xml", "yaml", "json",
    -- popular languages, mainly for fenced code blocks in markdown
    "rust", "go", "gomod", "gosum", "gowork", "javascript", "typescript", "tsx",
    "jsdoc", "java", "kotlin", "swift", "ruby", "php", "scala", "haskell",
    "elixir", "erlang", "zig", "c_sharp", "objc", "cuda", "glsl", "sql",
    "toml", "ini", "css", "scss", "graphql", "vue", "svelte", "hcl",
    "terraform", "proto", "perl", "r", "julia", "nix", "powershell", "groovy",
    "make", "just", "awk", "jq", "regex", "printf", "comment", "luadoc",
    "luap", "latex",
}

-- nvim-treesitter (main branch) shells out to the `tree-sitter` CLI to build
-- parsers. If it's missing, download a prebuilt binary into ~/.local/bin —
-- already on PATH per ~/.bashrc — so the FileType autocmd below can use it
-- on the next nvim startup.
local function ensure_tree_sitter_cli()
    if vim.fn.executable('tree-sitter') == 1 then
        return true
    end

    local bin_dir = vim.fn.expand('~/.local/bin')
    local bin_path = bin_dir .. '/tree-sitter'

    local uname = vim.uv.os_uname()
    local platform
    if uname.sysname == 'Linux' then
        if uname.machine == 'x86_64' then platform = 'linux-x64'
        elseif uname.machine == 'aarch64' then platform = 'linux-arm64'
        end
    elseif uname.sysname == 'Darwin' then
        if uname.machine == 'arm64' then platform = 'macos-arm64'
        elseif uname.machine == 'x86_64' then platform = 'macos-x64'
        end
    end

    if not platform then
        vim.notify(
            string.format('tree-sitter CLI: unsupported platform %s/%s',
                uname.sysname, uname.machine),
            vim.log.levels.WARN)
        return false
    end

    vim.fn.mkdir(bin_dir, 'p')
    -- Pin to v0.25.10: v0.26+ Linux binaries require GLIBC 2.39 (Ubuntu 24.04+).
    -- Bump once we're past the Ubuntu 22.04 baseline.
    local version = 'v0.25.10'
    local url = string.format(
        'https://github.com/tree-sitter/tree-sitter/releases/download/%s/tree-sitter-%s.gz',
        version, platform)
    local script = string.format(
        'curl -fsSL %q -o %q.gz && gunzip -f %q.gz && chmod +x %q',
        url, bin_path, bin_path, bin_path)

    vim.notify('Installing tree-sitter CLI to ' .. bin_path .. ' ...', vim.log.levels.INFO)
    local result = vim.system({ 'sh', '-c', script }, { text = true }):wait()
    if result.code ~= 0 then
        vim.notify('Failed to install tree-sitter CLI: ' .. (result.stderr or ''),
            vim.log.levels.ERROR)
        return false
    end

    vim.notify('Installed tree-sitter CLI: ' .. bin_path, vim.log.levels.INFO)
    return true
end

local ok_ts, ts = pcall(require, 'nvim-treesitter')
if ok_ts and ensure_tree_sitter_cli() then
    ts.install(ts_parsers)
    vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
            pcall(vim.treesitter.start, args.buf)
        end,
    })
end

-- in-buffer markdown rendering
pcall(function()
    require("render-markdown").setup({
        -- keep the cursor line rendered too (concealcursor is adjusted automatically)
        anti_conceal = { enabled = false },
        heading = {
            width = "block",
            left_pad = 2,
            right_pad = 4,
        },
        code = {
            style = "normal",
            width = "block",
            left_pad = 1,
            right_pad = 1,
        },
    })

    -- one distinct hue per heading level: fg colors the heading text and
    -- icon (RenderMarkdownH* links to @markup.heading.*), bg the heading band
    local heading_colors = {
        { fg = "#79c0ff", bg = "#1f3a5f" }, -- blue
        { fg = "#56d4dd", bg = "#17474c" }, -- cyan
        { fg = "#7ee787", bg = "#1d4428" }, -- green
        { fg = "#e3b341", bg = "#4a3910" }, -- yellow
        { fg = "#ffa657", bg = "#553117" }, -- orange
        { fg = "#d2a8ff", bg = "#40265a" }, -- purple
    }

    local function md_highlights()
        for level, c in ipairs(heading_colors) do
            vim.api.nvim_set_hl(0, "@markup.heading." .. level .. ".markdown", { fg = c.fg, bold = true })
            vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level .. "Bg", { bg = c.bg })
        end
        vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "#2a2a2a" })
        vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { bg = "#2a2a2a" })
    end

    -- defer so we apply after render-markdown's own ColorScheme handler
    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function() vim.schedule(md_highlights) end,
    })
    vim.schedule(md_highlights)
end)

-- <leader>yy yanks the markdown code block under the cursor (honors "x prefixes),
-- <leader>Y yanks it to the clipboard ("+);
-- lua/md_yank.lua needs only the markdown parser, not render-markdown
vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(args)
        vim.keymap.set("n", "<leader>yy", function()
            require("md_yank").code()
        end, { buffer = args.buf, desc = "Yank code block under cursor" })
        vim.keymap.set("n", "<leader>Y", function()
            require("md_yank").code("+")
        end, { buffer = args.buf, desc = "Yank code block under cursor to clipboard" })
    end,
})

-- smooth scrolling (smoothie.nvim); the key list is g:smoothie_remapped_commands in ~/.vim/plugins.vim
local ok_smoothie, smoothie = pcall(require, 'smoothie')
if ok_smoothie then
    smoothie.setup({
        keys = vim.g.smoothie_remapped_commands,
        quiet = true,
        duration = 500,
        max_filesize = 2 * 1024 * 1024,
    })
end

-- search lens (nvim-hlslens): [index/total] next to the matches. Set up before
-- the scrollbar, whose search marks come from it; start() does nothing until
-- setup() has enabled it.
require("hlslens").setup()

-- scrollbar on the right edge, shown in every window all the time, with the
-- search matches from hlslens. Marks take their highlight's foreground, and
-- the theme's Search has only a background (unset reads as black), so color
-- the search marks with that background, like the matches in the buffer.
local search_bg = vim.api.nvim_get_hl(0, { name = "Search", link = false }).bg
require("scrollbar").setup({
    show = true,
    show_in_active_only = false,
    hide_if_all_visible = false,
    handlers = { search = true },
    marks = {
        Search = { color = search_bg and string.format("#%06x", search_bg) or nil },
    },
})

-- smoothie owns n N * # g* g#: keep its scroll, then start the lens (and the
-- scrollbar search marks). Scheduled: when smoothie doesn't animate it feeds
-- the key, so the jump happens after this callback returns.
if ok_smoothie then
    for _, key in ipairs({ "n", "N", "*", "#", "g*", "g#" }) do
        vim.keymap.set("n", key, function()
            smoothie._map(key)
            vim.schedule(function() require("hlslens").start() end)
        end, { desc = "smoothie scroll + hlslens" })
    end
end

require("toggleterm").setup()

function _G.set_terminal_keymaps()
  local opts = {buffer = 0}
  vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
  vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
  vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
  vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
  vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
  vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
  vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
end

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

winmove = require('winmove')
vim.keymap.set('n', '<C-w>m', function() winmove.start_mode(winmove.Mode.Move) end, { noremap = true })
vim.keymap.set('n', '<C-w>s', function() winmove.start_mode(winmove.Mode.Swap) end, { noremap = true })
vim.keymap.set('n', '<C-w>r', function() winmove.start_mode(winmove.Mode.Resize) end, { noremap = true })




-- cscope

require('cscope_maps').setup({
    prefix = "<leader>s",
    exec = "cscope",
    cscope = {
        picker = "fzf-lua",
    },
    stack_view = {
        tree_hl = true, -- toggle tree highlighting
    }
})


-- coc: <c-space> triggers completion (Vim maps it as <c-@> in ~/.vimrc)
vim.keymap.set("i", "<c-space>", "coc#refresh()", { silent = true, expr = true })


-- fzf-lua (Vim maps the same keys to fzf.vim commands in ~/.vimrc)
vim.keymap.set("n", "<c-p>", ":FzfLua files<cr>", { remap = true })
vim.keymap.set("n", "<M-p>", ":FzfLua git_files<cr>", { remap = true })
vim.keymap.set("n", "<F5>", ":FzfLua buffers<cr>")
vim.keymap.set("n", "<F6>", ":FzfLua zoxide<cr>")
vim.keymap.set("n", "<F7>", ":FzfLua grep_project<cr>")
vim.keymap.set("n", "<S-F7>", ":FzfLua live_grep<cr>")
vim.keymap.set("n", "<F8>", ":FzfLua command_history<cr>")
vim.keymap.set("n", "<F9>", ":FzfLua blines<cr>")
vim.keymap.set("n", "<S-F9>", ":FzfLua lines<cr>")
vim.keymap.set("n", "<F10>", ":FzfLua git_bcommits<cr>")
vim.keymap.set("n", "<S-F10>", ":FzfLua git_commits<cr>")


-- git change signs (gitsigns). ]c [c \hs \hu \hp are the same keys vim-gitgutter
-- has in Vim; the rest are gitsigns only.
require("gitsigns").setup({
    on_attach = function(bufnr)
        local gitsigns = require("gitsigns")

        local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        local function selected_lines()
            return { vim.fn.line("."), vim.fn.line("v") }
        end

        -- in diff mode ]c [c keep their diff meaning
        map("n", "]c", function()
            if vim.wo.diff then
                vim.cmd.normal({ "]c", bang = true })
            else
                gitsigns.nav_hunk("next")
            end
        end, "next hunk")
        map("n", "[c", function()
            if vim.wo.diff then
                vim.cmd.normal({ "[c", bang = true })
            else
                gitsigns.nav_hunk("prev")
            end
        end, "previous hunk")

        map("n", "<leader>hs", gitsigns.stage_hunk, "stage hunk (again to unstage)")
        map("n", "<leader>hu", gitsigns.reset_hunk, "undo hunk")
        map("n", "<leader>hp", gitsigns.preview_hunk, "preview hunk")
        map("v", "<leader>hs", function() gitsigns.stage_hunk(selected_lines()) end, "stage lines")
        map("v", "<leader>hu", function() gitsigns.reset_hunk(selected_lines()) end, "undo lines")
        map("n", "<leader>hS", gitsigns.stage_buffer, "stage buffer")
        map("n", "<leader>hU", gitsigns.reset_buffer, "undo buffer")
        map("n", "<leader>hi", gitsigns.preview_hunk_inline, "preview hunk inline")
        map("n", "<leader>hb", function() gitsigns.blame_line({ full = true }) end, "blame line")
        map("n", "<leader>hd", gitsigns.diffthis, "diff against index")
        map("n", "<leader>hD", function() gitsigns.diffthis("~") end, "diff against last commit")
        map("n", "<leader>hq", gitsigns.setqflist, "buffer hunks to quickfix")
        map("n", "<leader>hQ", function() gitsigns.setqflist("all") end, "repo hunks to quickfix")
        map("n", "<leader>tb", gitsigns.toggle_current_line_blame, "toggle line blame")
        map("n", "<leader>tw", gitsigns.toggle_word_diff, "toggle word diff")
        map({ "o", "x" }, "ih", gitsigns.select_hunk, "hunk text object")
    end,
})

-- git changes on the scrollbar
require("scrollbar.handlers.gitsigns").setup()


-- octo (GitHub PRs / reviews through gh)

-- Octo adds github.com-only GraphQL fields while github_hostname is "", which a
-- GHES host rejects, so take the host from the repo nvim starts in
local function git_remote_host()
    for _, name in ipairs({ "upstream", "origin" }) do
        local url = vim.fn.systemlist({ "git", "remote", "get-url", name })[1]
        if vim.v.shell_error == 0 and url then
            return url:gsub("^%w+://", ""):gsub("^[^@/]*@", ""):match("^[^:/]+")
        end
    end
end

local ok_octo, octo = pcall(require, "octo")
if ok_octo then
    local host = git_remote_host()
    octo.setup({
        picker = "fzf-lua",
        enable_builtin = true,
        github_hostname = (host and host ~= "github.com") and host or "",
    })
    vim.treesitter.language.register("markdown", "octo")
end
