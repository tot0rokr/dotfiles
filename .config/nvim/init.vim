" Python provider from the venv built by `dotfiles bootstrap user`.
let s:py3_host = stdpath('data') .. '/venv/bin/python'
if executable(s:py3_host)
  let g:python3_host_prog = s:py3_host
endif

" Neovim only. Vim starts from ~/.config/vim/vimrc; both editors read the
" shared plugin list (plugins.vim) and settings (common.vim) in the vim/ dir
" beside this one.
let g:local_data_dir = stdpath('state')
let s:vimdir = fnamemodify(stdpath('config'), ':h') .. '/vim'

" Settings come before lazy.nvim loads the plugins, as they do in Vim, so the
" variables plugins read at load time are already set.
lua require('plugin_manager').read_shared_list()
exe 'source' fnameescape(s:vimdir .. '/common.vim')
lua require('plugin_manager').setup()

lua require('init')

" Last, as at the end of ~/.config/vim/vimrc: common.vim's code that calls
" plugin functions, the session restore and ~/.vimrc_adv.
if exists('#User#PluginsReady')
    doautocmd <nomodeline> User PluginsReady
endif

" $MYVIMRC is the shared settings in both editors; $INITVIM is this editor's
" entry file (~/.config/vim/vimrc in Vim).
let $MYVIMRC = s:vimdir .. '/common.vim'
let $INITVIM = stdpath('config') .. '/init.vim'
let $INITLUA = stdpath('config') .. '/lua/init.lua'

" Account-local hook (untracked), run last. Multi-line on purpose: :lua takes
" the rest of its line, a `|` included, as Lua code.
if filereadable(stdpath('config') .. '/lua/local.lua')
  lua require('local')
endif
