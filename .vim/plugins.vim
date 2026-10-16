" Plugins shared by Vim and Neovim.
" ~/.vimrc sources this between plug#begin() and plug#end(). Neovim reads it
" through lua/plugin_manager.lua, which turns each Plug line into a lazy.nvim
" spec and accepts only these vim-plug options: on, for, do, branch.
" Plugins for one editor only go in ~/.vimrc (Vim) or lua/plugins/ (Neovim).

Plug 'tpope/vim-sensible' " normal setup

Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }

" File finder
" Plug 'ctrlpvim/ctrlp.vim'
" Instead of ctrlp.vim, use fzf

" theme (schema)
"Plug 'junegunn/seoul256.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'edkolev/tmuxline.vim'

" keyword tag bar
Plug 'majutsushi/tagbar'

" auto completion
" Need nodejs
" $ curl -sL install-node.vercel.app/lts | bash
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" write comment
Plug 'scrooloose/nerdcommenter'

" ctags
Plug 'xolox/vim-misc'

" easymotion
Plug 'easymotion/vim-easymotion'

" argument movable
Plug 'peterrincker/vim-argumentative'

" git
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'
" git conlict. required tpope/vim-fugitive
Plug 'christoomey/vim-conflicted'


" line orient
" Plug 'tommcdo/vim-lion'

" MarkDown
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && npx --yes yarn install' }

" code break game
Plug 'johngrib/vim-game-code-break'

" REST API
Plug 'diepm/vim-rest-console'

" diff character
" Plug 'vim-scripts/diffchar.vim'

" > Plug ALE
" Plug 'dense-analysis/ale'
" > let g:ale_completion_enabled = 1
" > set omnifunc=ale#completion#OmniFunc
" let g:ale_lint_on_text_changed = 'never'
" let g:ale_lint_on_enter = 0

" Icon
Plug 'ryanoasis/vim-devicons'

" swap recovery
Plug 'chrisbra/Recover.vim'

" docstring
" Need to make install
" $ cd ~/.vim/bundle/vim-pydocstring
" $ make install
Plug 'heavenshell/vim-pydocstring', { 'do': 'make install', 'for': 'python' }

" quickui
" Plug 'skywind3000/vim-quickui'
Plug 'tot0rokr/vim-quickui'

" fzf
" fzf itself is not a plugin here: install_fzf_user (.bashrc.common) keeps it in
" ~/.fzf, and both editors only add that directory to 'runtimepath'.
Plug 'junegunn/fzf.vim'

" Tab
Plug 'gcmt/taboo.vim'

" Session save
Plug 'tpope/vim-obsession'

" Snippets
" Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'

" Flutter
Plug 'dart-lang/dart-vim-plugin'
" Plug 'natebosch/vim-lsc'
" Plug 'natebosch/vim-lsc-dart'
" let g:lsc_auto_map = v:true

" Code context viewer
" Plug 'wellle/context.vim'
Plug 'tot0rokr/context.vim'
" set rtp+=$HOME/context.vim
" Plug '~/context.vim'

" Multi Cursor
Plug 'mg979/vim-visual-multi', {'branch': 'master'}

" Window Manager
" Plug 'tot0rokr/vim-wm.vim'

" Keymap
Plug 'liuchengxu/vim-which-key'


" vim-smoothie (Vim) / smoothie.nvim (Neovim): which keys get smooth-scroll
" animation. MUST be set before the plugins load -- vim-smoothie builds these
" mappings at load time (the speed tuning in ~/.vimrc is read at runtime).
let g:smoothie_remapped_commands =
      \ ['<C-D>','<C-U>','<C-F>','<C-B>','<S-Down>','<PageDown>','<S-Up>','<PageUp>',
      \  'z+','z^','zt','z<CR>','z.','zz','z-','zb',
      \  'gg','G','{','}','H','M','L','n','N','*','#','g*','g#']
