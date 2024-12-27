set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath=&runtimepath
source ~/.vimrc

lua require('init')

let $MYVIMRC = expand('~/.vimrc')
let $INITVIM = expand('~/.config/nvim/init.vim')
let $INITLUA = expand('~/.config/nvim/lua/init.lua')
