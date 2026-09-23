" Python provider from the venv built by install_pynvim_user (.bashrc.common).
let s:py3_host = expand('~/.local/share/nvim/venv/bin/python')
if executable(s:py3_host)
  let g:python3_host_prog = s:py3_host
endif

set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath=&runtimepath
source ~/.vimrc

lua require('init')

let $MYVIMRC = expand('~/.vimrc')
let $INITVIM = expand('~/.config/nvim/init.vim')
let $INITLUA = expand('~/.config/nvim/lua/init.lua')
