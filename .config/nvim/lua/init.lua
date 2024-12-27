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


-- Copilot
local CopilotChat = require("CopilotChat")

CopilotChat.setup {
    -- See Configuration section for options
    mappings = {
        reset = {
            normal = '<M-l>',
            insert = '',
        },
    },
    -- window = {
      -- layout = 'float',
      -- relative = 'cursor',
      -- width = 1,
      -- height = 0.4,
      -- row = 1
    -- }
}
local CopilotPrompts = CopilotChat.config.prompts
local additional_prompt = " Says In Korean."

for _, prompt in pairs(CopilotPrompts) do
    prompt.prompt = prompt.prompt .. additional_prompt
end

