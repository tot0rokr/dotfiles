-- Plugins that run only in Neovim; plugins Vim can use too go in
-- ~/.vim/plugins.vim. Their setup() calls are in lua/init.lua.
return {
    -- theme (schema)
    {
        "projekt0n/github-nvim-theme",
        priority = 1000,
        config = function()
            vim.o.termguicolors = true
            -- colorscheme github_dark
            -- colorscheme github_light
            -- colorscheme github_dark_dimmed
            -- colorscheme github_dark_default
            -- colorscheme github_dark_dimmed
            -- colorscheme github_dark_default
            -- colorscheme github_dark_muted
            -- colorscheme github_dark_high_contrast
            -- colorscheme github_dark_soft
            vim.cmd.colorscheme("github_dark_colorblind")
            -- colorscheme github_dark_light
            -- colorscheme github_dark_light_dimmed
            -- colorscheme github_dark_light_default
            -- colorscheme github_dark_light_muted
            -- colorscheme github_dark_light_high_contrast
            -- colorscheme github_dark_light_soft
            -- colorscheme github_dark_light_colorblind
            vim.o.winhighlight = "Normal:MyNormal,NormalNC:MyNormalNC,NormalSB:MyNormalNC"
            vim.cmd([[
                highlight Normal guifg=#c9d1d9 guibg=None
                highlight NormalNC guibg=NONE
                highlight NormalSB guibg=NONE
                highlight MyNormal guifg=#c9d1d9 guibg=#0d1117    " github_dark_colorblind
                highlight MyNormalNC guifg=#c9d1d9 guibg=None
            ]])
        end,
    },

    -- MarkDown
    "MeanderingProgrammer/render-markdown.nvim",

    -- indent guide
    "lukas-reineke/indent-blankline.nvim",

    -- Highlight
    "HiPhish/rainbow-delimiters.nvim",
    -- parsers must match the plugin's queries, so rebuild them on every update
    { "nvim-treesitter/nvim-treesitter", branch = "main", build = ":TSUpdate" },

    -- fzf
    "ibhagwan/fzf-lua",

    -- Shell
    { "akinsho/toggleterm.nvim", version = "*" },

    -- Scrolling
    "tot0rokr/smoothie.nvim",
    "petertriho/nvim-scrollbar",
    "kevinhwang91/nvim-hlslens",

    -- Window Manager
    "MisanthropicBit/winmove.nvim",

    -- Command Line
    "folke/noice.nvim",
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",

    -- nvim cscope
    "dhananjaylatkar/cscope_maps.nvim",

    -- Git change signs (Vim uses vim-gitgutter, ~/.vimrc)
    "lewis6991/gitsigns.nvim",

    -- GitHub PR review / issues (Octo); talks to GitHub through the gh CLI
    "nvim-lua/plenary.nvim",
    "pwntester/octo.nvim",
}
