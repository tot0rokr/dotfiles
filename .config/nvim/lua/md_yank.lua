-- Yank the content of the markdown fenced code block under the cursor.
-- Standalone port of yank_code from the ~/render-markdown.nvim fork: needs
-- only the markdown treesitter parser, not render-markdown.

local M = {}

---@param message string
---@param level integer
local function notify(message, level)
    vim.notify(('md_yank: %s'):format(message), level)
end

---outermost code block containing the position, injections are ignored so a
---code block nested in a markdown code block yanks the outer one
---@param buf integer
---@param row integer
---@param col integer
---@return TSNode?
local function find_block(buf, row, col)
    local parser = vim.treesitter.get_parser(buf, 'markdown', { error = false })
    if not parser then
        return nil
    end
    parser:parse({ row, row })
    local node = vim.treesitter.get_node({
        bufnr = buf,
        pos = { row, col },
        lang = 'markdown',
    })
    while node and node:type() ~= 'fenced_code_block' do
        node = node:parent()
    end
    return node
end

---content rows of the block, without the fences or the prefix of its
---container (list indent, block quote marker)
---@param buf integer
---@param block TSNode
---@return string[]
local function block_lines(buf, block)
    -- content rows start after a block_continuation, which covers the prefix
    local content = nil ---@type TSNode?
    local prefixes = {} ---@type table<integer, integer>
    local function collect(node)
        for child in node:iter_children() do
            local kind = child:type()
            if kind == 'block_continuation' then
                local row, _, _, end_col = child:range()
                prefixes[row] = end_col
            elseif kind == 'code_fence_content' then
                content = child
                collect(child)
            end
        end
    end
    collect(block)
    if not content then
        return {}
    end
    local start_row, start_col, end_row, end_col = content:range()
    prefixes[start_row] = start_col
    -- content ends at the prefix of the closing fence row
    if end_col <= (prefixes[end_row] or 0) then
        end_row = end_row - 1
    end
    local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row + 1, false)
    for i, line in ipairs(lines) do
        lines[i] = line:sub((prefixes[start_row + i - 1] or 0) + 1)
    end
    return lines
end

---yank the code block under the cursor linewise
---@param register? string defaults to v:register
function M.code(register)
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local block = find_block(buf, row - 1, col)
    if not block then
        notify('no code block under cursor', vim.log.levels.WARN)
        return
    end
    local lines = block_lines(buf, block)
    if #lines == 0 then
        notify('code block is empty', vim.log.levels.WARN)
        return
    end
    vim.fn.setreg(register or vim.v.register, lines, 'l')
    -- same message as a builtin linewise yank
    local plural = #lines == 1 and '' or 's'
    vim.api.nvim_echo({ { ('%d line%s yanked'):format(#lines, plural) } }, true, {})
end

return M
