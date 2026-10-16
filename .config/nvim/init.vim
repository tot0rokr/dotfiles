" Python provider from the venv built by install_pynvim_user (.bashrc.common).
let s:py3_host = expand('~/.local/share/nvim/venv/bin/python')
if executable(s:py3_host)
  let g:python3_host_prog = s:py3_host
endif

" Neovim only. Vim starts from ~/.vimrc; both editors read the shared plugin
" list (~/.vim/plugins.vim) and settings (~/.vim/common.vim).
let g:local_data_dir = $HOME .. '/.local/share/nvim'

" Settings come before lazy.nvim loads the plugins, as they do in Vim, so the
" variables plugins read at load time are already set.
lua require('plugin_manager').read_shared_list()
source ~/.vim/common.vim
lua require('plugin_manager').setup()

lua require('init')

" Last, as at the end of ~/.vimrc: common.vim's code that calls plugin
" functions, the session restore and ~/.vimrc_adv.
if exists('#User#PluginsReady')
    doautocmd <nomodeline> User PluginsReady
endif

let $MYVIMRC = expand('~/.vimrc')
let $INITVIM = expand('~/.config/nvim/init.vim')
let $INITLUA = expand('~/.config/nvim/lua/init.lua')
