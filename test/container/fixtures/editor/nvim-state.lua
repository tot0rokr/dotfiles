-- A04: writes the nvim state the checks look at to $T_RESULT as key=value
-- lines, then quits.
local out = {}
local function put(key, value)
    if value == nil then
        value = ""
    end
    out[#out + 1] = key .. "=" .. tostring(value)
end

put("errmsg", vim.v.errmsg)
put("local", vim.g.dotfiles_t_local)
put("plugins_local", vim.g.dotfiles_t_plugins_local)
put("state", vim.fn.stdpath("state"))
put("data", vim.fn.stdpath("data"))
put("undodir", vim.o.undodir)
put("directory", vim.o.directory)
put("backupdir", vim.o.backupdir)
put("obsession_dir", vim.g.obsession_dir)
put("rtp_fzf", vim.tbl_contains(vim.opt.rtp:get(), vim.fn.expand("~/.local/opt/fzf")))
put("python3", vim.fn.has("python3"))
put("python3_host_prog", vim.g.python3_host_prog)
vim.fn.writefile(out, os.getenv("T_RESULT"))
vim.cmd("qa!")
