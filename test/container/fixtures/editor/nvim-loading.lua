-- A01: every lazy.nvim plugin is installed and the shared commands exist.
-- Writes one line per problem to $T_RESULT (an empty file means none).
local problems = {}
local ok, lazy = pcall(require, "lazy")
if not ok then
    problems[#problems + 1] = "lazy.nvim is not loaded"
else
    for _, p in ipairs(lazy.plugins()) do
        if not (p._ and p._.installed) then
            problems[#problems + 1] = "not installed: " .. p.name
        end
    end
end
if vim.fn.exists(":Conflicted") ~= 2 then
    problems[#problems + 1] = "no :Conflicted command"
end
if vim.fn.exists("*fzf#run") ~= 1 then
    problems[#problems + 1] = "no fzf#run() function"
end
if vim.fn.exists(":LS") ~= 2 then
    problems[#problems + 1] = "no :LS command"
end
vim.fn.writefile(problems, os.getenv("T_RESULT"))
vim.cmd("qa!")
