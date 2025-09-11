" Vim Set Up
" Language: vim-script
" Author:   Junho Lee (TOT0Ro)

let g:vimdir = $HOME .. '/.vim'
if has('nvim')
    let g:local_data_dir = $HOME .. '/.local/share/nvim'
else
    let g:local_data_dir = $HOME .. '/.vim'
endif

function! s:check_installed_plugin(name)
    if empty(glob(g:local_data_dir . '/plugged/' . a:name))
        return v:false
    elseif match(&rtp, a:name) == -1
        return v:false
    else
        return v:true
endfunction

" -------------------------------- Plugin -----------------------------------

call plug#begin()
" The default plugin directory will be as follows:
"   - Vim (Linux/macOS): '~/.vim/plugged'
"   - Vim (Windows): '~/vimfiles/plugged'
"   - Neovim (Linux/macOS/Windows): stdpath('data') . '/plugged'
" You can specify a custom plugin directory by passing it as the argument
"   - e.g. `call plug#begin('~/.vim/plugged')`
"   - Avoid using standard Vim directory names like 'plugin'

Plug 'tpope/vim-sensible' " normal setup

Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }

" File finder
" Plug 'ctrlpvim/ctrlp.vim'
" Instead of ctrlp.vim, use fzf

" theme (schema)
"Plug 'junegunn/seoul256.vim'
if has('nvim')
    Plug 'projekt0n/github-nvim-theme'
endif
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

" indent guide
if has('nvim')
    Plug 'lukas-reineke/indent-blankline.nvim'
else
    Plug 'nathanaelkane/vim-indent-guides'
endif

" Highlight
if has('nvim')
    Plug 'HiPhish/rainbow-delimiters.nvim'
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
endif

" docstring
" Need to make install
" $ cd ~/.vim/bundle/vim-pydocstring
" $ make install
Plug 'heavenshell/vim-pydocstring', { 'do': 'make install', 'for': 'python' }

" quickui
" Plug 'skywind3000/vim-quickui'
Plug 'tot0rokr/vim-quickui'

" fzf
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
if has('nvim')
    Plug 'ibhagwan/fzf-lua'
endif

" Shell
if !has('nvim')
    Plug 'Shougo/deol.nvim'
else
    Plug 'akinsho/toggleterm.nvim', {'tag' : '*'}
endif

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

" Scrolling
Plug 'opalmay/vim-smoothie'

" Code minimap
Plug 'wfxr/minimap.vim', {'do': ':!cargo install --locked code-minimap'}

" Code context viewer
" Plug 'wellle/context.vim'
Plug 'tot0rokr/context.vim'
" set rtp+=$HOME/context.vim
" Plug '~/context.vim'

" Multi Cursor
Plug 'mg979/vim-visual-multi', {'branch': 'master'}

" Window Manager
" Plug 'tot0rokr/vim-wm.vim'
Plug 'MisanthropicBit/winmove.nvim'

" AI LLM
Plug 'github/copilot.vim'
if has('nvim')
    Plug 'nvim-lua/plenary.nvim'
    Plug 'CopilotC-Nvim/CopilotChat.nvim'
endif

" Keymap
Plug 'liuchengxu/vim-which-key'

" Command Line
if has('nvim')
    Plug 'folke/noice.nvim'
    Plug 'MunifTanjim/nui.nvim'
    Plug 'rcarriga/nvim-notify'
endif

" nvim cscope
if has('nvim')
    Plug 'dhananjaylatkar/cscope_maps.nvim'
endif

" Initialize plugin system
" - Automatically executes `filetype plugin indent on` and `syntax enable`.
call plug#end()
" You can revert the settings after the call like so:
"   filetype indent off   " Disable file-type-specific indentation
"   syntax off            " Disable syntax highlighting

" ------------------------------- setup --------------------------------------

" Uppercase, number of marks, maximum lines are saved for each register,
" size limit for a register, nohisearch
set viminfo=!,'1000,<1000,s100,/1000,:1000,@1000,h
" May need for Vim (not Neovim) since coc.nvim calculates byte offset by count
" utf-8 byte sequence
set encoding=utf-8
" Having longer updatetime (default is 4000 ms = 4s) leads to noticeable
" delays and poor user experience
set updatetime=300
set signcolumn=yes
highlight SignColumn ctermbg=none
set fencs=utf-8,euc-kr,ucs-bom,korea

" side (vertical) scroll
set nowrap
set sidescroll=1
set sidescrolloff=10

set background=dark
" set t_Co=16
set t_Co=256
set autoread
autocmd CursorHold * :checktime
set hlsearch

" Use mount options
set mouse=v


set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent
set textwidth=100
set formatoptions-=t

autocmd FileType c setlocal ts=8 sts=8 sw=8 noexpandtab cc=+0 tw=80
autocmd FileType cpp setlocal ts=8 sts=8 sw=8 noexpandtab cc=+0
autocmd FileType vim setlocal ts=4 sts=4 sw=4 expandtab cc=+0
autocmd FileType python setlocal ts=4 sts=4 sw=4 expandtab tw=88 cc=+0
autocmd FileType markdown setlocal ts=4 sts=4 sw=4 expandtab tw=100 cc=+0
autocmd FileType html setlocal ts=4 sts=4 sw=4 expandtab tw=100 cc=+0

" ------------------------------- Theme -----------------------------------
" ColorScheme
if s:check_installed_plugin('github-nvim-theme')
if has('nvim')
    " set termguicolors
    " colorscheme github_dark
    " colorscheme github_light
    " colorscheme github_dark_dimmed
    " colorscheme github_dark_default
    " colorscheme github_dark_dimmed
    " colorscheme github_dark_default
    " colorscheme github_dark_muted
    " colorscheme github_dark_high_contrast
    " colorscheme github_dark_soft
    colorscheme github_dark_colorblind
    " colorscheme github_dark_light
    " colorscheme github_dark_light_dimmed
    " colorscheme github_dark_light_default
    " colorscheme github_dark_light_muted
    " colorscheme github_dark_light_high_contrast
    " colorscheme github_dark_light_soft
    " colorscheme github_dark_light_colorblind
    set winhighlight=Normal:MyNormal,NormalNC:MyNormalNC,NormalSB:MyNormalNC
    highlight Normal guifg=#c9d1d9 guibg=None
    highlight NormalNC guibg=NONE
    highlight NormalSB guibg=NONE
    highlight MyNormal guifg=#c9d1d9 guibg=#0d1117    " github_dark_colorblind
    highlight MyNormalNC guifg=#c9d1d9 guibg=None
endif
endif

" --------------------------- COMMIT_EDITMSG ---------------------------------
autocmd BufEnter COMMIT_EDITMSG set textwidth=72 cc=+0 formatoptions+=t
autocmd BufEnter COMMIT_EDITMSG highlight CommitEditor ctermbg=105 cterm=None guibg=#8787ff
autocmd BufEnter COMMIT_EDITMSG match CommitEditor '\%1l\%50v'

" ------------------------- 라인 끝 공백 highlight --------------------------
highlight ExtraWhitespace ctermbg=88 guibg=#870000
match ExtraWhitespace /\s\+$/
function! ExtraWhitespaceIfNofile()
    if &buftype ==# '' && &bufhidden ==# ''
        match ExtraWhitespace /\s\+$/
    endif
endfunction
autocmd WinEnter * call ExtraWhitespaceIfNofile()
autocmd WinLeave * call clearmatches()

" ------------------------------- tab -----------------------------------
if s:check_installed_plugin('taboo.vim')
set sessionoptions+=tabpages,globals
let g:taboo_tab_format=' %f%m%U '
let g:taboo_renamed_tab_format=' <%l>%m%U '
let g:taboo_modified_tab_flag='+'
endif

" ------------------------------- Indent -----------------------------------
if s:check_installed_plugin('vim-indent-guides')
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd ctermbg=235 guibg=#262626
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=237 guibg=#3a3a3a
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
let g:indent_guides_default_mapping = 0
endif

" ------------------------------- NERD Commenter -----------------------------------
if s:check_installed_plugin('nerdcommenter')
let g:NERDSpaceDelims=1
endif

" ------------------------------- MarkDown -----------------------------------
if s:check_installed_plugin('markdown-preview.nvim')
nmap <leader><leader>m <Plug>MarkdownPreviewToggle
endif

" ---------------------------------- folding ---------------------------------
set foldmethod=manual
set foldnestmax=2
set foldlevel=0
set foldcolumn=0
exec 'set fillchars=fold:\ '

function! MyFoldText()
    let nl = v:foldend - v:foldstart + 1
    let txt = getline(v:foldstart) .. ' --- length ' .. nl .. ' '
    return txt
endfunction
set foldtext=MyFoldText()
nnoremap <space><space> za
vnoremap <space><space> zf
highlight FoldColumn ctermfg=3 ctermbg=none guifg=#808000
highlight Folded ctermfg=245 ctermbg=none guifg=#8a8a8a

let foldfiles = {
            \ 'python': g:vimdir .. '/python_fold.vim'
            \}
" let python_fold = findfile(foldfiles.python)
if exists("python_fold")
    exec 'autocmd FileType python source ' .. python_fold
endif

function! FindDeepestFoldLevel()
    let maxFoldLevel = 0
    for i in range(1, line('$'))
        let currentFoldLevel = foldlevel(i)
        if currentFoldLevel > maxFoldLevel
            let maxFoldLevel = currentFoldLevel
        endif
    endfor
    return maxFoldLevel
endfunction

function! ToggleFoldColumn()
    if &foldcolumn
        set foldcolumn=0
    else
        let max_fold_level = FindDeepestFoldLevel()
        if max_fold_level > 0
            let max_fold_level += 1
        endif
        exec 'set foldcolumn=' .. max_fold_level
    endif
endfunction

command! FoldColumn call ToggleFoldColumn()

" ---------------------------------- docstring ---------------------------------
if s:check_installed_plugin('vim-pydocstring')
let g:pydocstring_formatter = 'google'
let g:pydocstring_ignore_init = 1
let g:pydocstring_enable_mapping = 0
endif

" -------------------------------- quick fix --------------------------------
function! OpenQuickfixWindow()
    let length = len(getqflist())
    if length > 10
        let length = 10
    endif
    if length > 1
        exec "copen" .. length
    else
        exec "cclose"
    endif
endfunction

autocmd QuickFixCmdPost * :call OpenQuickfixWindow()
" autocmd BufReadPost quickfix setlocal modifiable
        " \ | silent exec 'g/^/s//\=line(".")." "/'
        " \ | setlocal nomodifiable

" Function to check if a command exists
function! CommandExists(cmd)
  return !empty(system('command -v ' . a:cmd))
endfunction

" -------------------------------- cursor ------------------------------------

set cursorline
set cursorcolumn
function! ToggleCursorHighlight ()
    if &cursorline && &cursorcolumn
        set nocursorline
        set nocursorcolumn
    else
        set cursorline
        set cursorcolumn
    endif
endfunction

" ------------------------------- ruler --------------------------------------

autocmd BufReadPre * let b:colorcolumns = &cc
function! ToggleRuler ()
    if &cc != '0'
        let b:colorcolumns = &cc
        exec 'set cc=0'
    else
        if !exists('b:colorcolumns')
            let b:colorcolumns = 0
        endif
        exec 'set cc=' .. b:colorcolumns
    endif
endfunction

hi CursorLine ctermbg=237 cterm=None guibg=#3a3a3a
hi CursorColumn ctermbg=237 cterm=None guibg=#3a3a3a
hi ColorColumn ctermbg=105 cterm=None guibg=#8787ff
" syntax enable
" set wmnu
" set nu

" ------------------------------- diff ----------------------------------------

" diff
highlight DiffAdd       ctermbg=22 guibg=#005f00
highlight DiffChange    ctermbg=54 guibg=#5f0087
highlight DiffDelete    ctermbg=88 guibg=#870000
highlight DiffText      ctermbg=237 guibg=#3a3a3a


" ------------------------------- copilot -----------------------------------------
if s:check_installed_plugin('copilot.vim')

let g:copilot_filetypes = {
    \ 'gitcommit': v:true,
    \ 'markdown': v:true,
    \ 'yaml': v:true,
    \ 'c': v:true,
    \ 'vim': v:true,
    \ 'python': v:true,
    \ 'lua ': v:true
    \ }
autocmd BufReadPre *
    \ let f=getfsize(expand("<afile>"))
    \ | if f > 100000 || f == -2
    \ | let b:copilot_enabled = v:false
    \ | endif

endif


" ------------------------------- Obsession ----------------------------------
" Obsession status
" - 0: disable
" - 1: enable
" - 2: not use
if s:check_installed_plugin('vim-obsession')
let g:obsession_no_bufenter = 1

function! ObsessionToggle()
    if g:obsession_status == 2
        execute "Obsession " .. g:obsession_swap
        let g:obsession_status = 1
    else
        execute "Obsession"
        let g:obsession_status = xor(g:obsession_status, 1)
    endif
endfunction

function! ObsessionDelete()
    if g:obsession_status != 2
        execute "Obsession!"
        let g:obsession_status = 2
        call delete(g:obsession_file)
    endif
endfunction

let g:obsession_dir = g:local_data_dir .. '/obsession'
if !isdirectory(g:obsession_dir)
    call mkdir(g:obsession_dir, "p", 0700)
endif
let g:obsession_filename = slice(substitute($PWD .. '/Session.vim', '/', '-', 'g'), 1)
let g:obsession_file = g:obsession_dir .. '/' .. g:obsession_filename
let g:obsession_swap = g:obsession_file .. '.swp'

" If Obsession is used and exist session swap file, to store session file.
function! ObsessionLeave()
    if (g:obsession_status != 2 && !empty(findfile(g:obsession_swap)))
        call writefile(readfile(g:obsession_swap), g:obsession_file)
        call delete(g:obsession_swap)
    endif
endfunction
au VimLeave * call ObsessionLeave()

" If executes without arguments and anybody is not use Obsession,
" load session file and enable Obsession.
if !get(g:, 'obsession_status')
    let g:obsession_status = 2
    if (!argc() && !empty(findfile(g:obsession_file)) && empty(findfile(g:obsession_swap)))
        call writefile(readfile(g:obsession_file), g:obsession_swap)
        let g:obsession_status = 1
        execute 'silent source ' .. g:obsession_swap
    endif
endif

endif

" ------------------------------- dart ----------------------------------------
if s:check_installed_plugin('dart-vim-plugin')
let g:dart_html_in_string = v:true
let g:dart_style_guide = 2
let g:dart_format_on_save = v:true
endif

" --------------------------- statusbar/ airline ------------------------------
set laststatus=2 " vim-airline을 위해 상태바 2줄
if s:check_installed_plugin('vim-airline')
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
" let g:airline#extensions#tabline#left_sep = ''
" let g:airline#extensions#tabline#left_alt_sep = ''
" let g:airline#extensions#tabline#right_sep = ''
" let g:airline#extensions#tabline#right_alt_sep = ''
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = ' '
let g:airline#extensions#tabline#right_sep = ' '
let g:airline#extensions#tabline#right_alt_sep = ' '
let g:airline#extensions#tabline#formatter = 'unique_tail'
let g:airline#extensions#tabline#tab_nr_type = 1
let g:airline#extensions#tabline#show_tab_nr = 1
let g:airline#extensions#tabline#tabtitle_formatter = 'TabTitleFormatter'
function TabTitleFormatter(n)
    return TabooTabTitle(0)
endfunction

let g:airline_theme='simple'

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
let g:airline_left_alt_sep = ''
let g:airline_right_alt_sep = ''
" let g:airline_left_sep = ''
" let g:airline_right_sep = ''
let g:airline_symbols.paste = ' '
let g:airline_left_sep = ' '
let g:airline_right_sep = ' '
" let g:airline_symbols.paste = 'PASTE'

function! GetObsessionSymbol()
    let status = g:obsession_status
    return status == 2 ? '' : status == 1 ? ' ' : ' '
    " return status == 2 ? '' : status == 1 ? '$' : 'S'
endfunction
call airline#parts#define(
       \ 'obsessionstatus', {'function': 'GetObsessionSymbol', 'accents': 'bold'})

function! GetWindowNumber()
    return ' 󱇛 ' .. tabpagewinnr(tabpagenr())
    " return ' W' .. tabpagewinnr(tabpagenr())
endfunction
call airline#parts#define(
       \ 'windownumber', {'function': 'GetWindowNumber', 'accents': 'bold'})

function! GetFoldLevel()
    return foldlevel(line('.')) > 0 ? '  ' .. foldlevel(line('.')) : ''
    " return foldlevel(line('.')) > 0 ? ' Z' .. foldlevel(line('.')) : ''
endfunction
call airline#parts#define(
       \ 'foldlevel', {'function': 'GetFoldLevel', 'accents': 'bold'})
let g:airline_section_a = airline#section#create_left(
       \ ['mode', 'crypt', 'paste', 'keymap', 'spell', 'capslock', 'xkblayout', 'iminsert', 'obsessionstatus'])
let g:airline_section_z = airline#section#create(
       \ ['%p%%', 'linenr', 'maxlinenr', 'colnr', 'foldlevel', 'windownumber'])
endif

if s:check_installed_plugin('tmuxline.vim')
let g:airline#extensions#tmuxline#enabled = 0
let g:tmuxline_preset = {
        \'a'    : '#S',
        \'b'    : '#W',
        \'c'    : '#H',
        \'win'  : ['#I', '#W#F'],
        \'cwin' : ['#I', '#W#F'],
        \'x'    : "#(date)",
        \'y'    : "#(uptime | cut -f 4-5 -d ' ' | cut -f 1 -d ',')",
        \'z'    : "#H"}
let g:tmuxline_separators = {
        \ 'left' : '',
        \ 'left_alt': '',
        \ 'right' : '',
        \ 'right_alt' : '',
        \ 'space' : ' '}
endif

" -------------------------- coc ----------------------------------------------
if s:check_installed_plugin('coc.nvim')
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ "\<TAB>"
      " \ CheckBackspace() ? "\<TAB>" :
      " \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" inoremap <silent><expr> <TAB>
      " \ coc#pum#visible() ? coc#_select_confirm() :
      " \ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
      " \ CheckBackspace() ? "\<TAB>" :
      " \ coc#refresh()

function! CheckBackspace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion
if has('nvim')
    inoremap <silent><expr> <c-space> coc#refresh()
else
    inoremap <silent><expr> <c-@> coc#refresh()
endif

" GoTo code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gt <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
    if CocAction('hasProvider', 'hover')
        call CocActionAsync('doHover')
    else
        call feedkeys('K', 'in')
    endif
endfunction

" Highlight the symbol and its references when holding the cursor
if exists('*CocActionAsync')
    autocmd CursorHold * silent call CocActionAsync('highlight')
endif

augroup mygroup
    autocmd!
    " Setup formatexpr specified filetype(s)
    autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
    " Update signature help on jump placeholder
    autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end


" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Remap <C-f> and <C-b> to scroll float windows/popups
if has('nvim-0.4.0') || has('patch-8.2.0750')
    nnoremap <silent><nowait><expr> <C-f>
            \ coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
    nnoremap <silent><nowait><expr> <C-b>
            \ coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
    inoremap <silent><nowait><expr> <C-f>
            \ coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
    inoremap <silent><nowait><expr> <C-b>
            \ coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
    vnoremap <silent><nowait><expr> <C-f>
            \ coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
    vnoremap <silent><nowait><expr> <C-b>
            \ coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
endif

" Mappings for CoCList
" Show all diagnostics
" Do default action for next item
nnoremap <silent><nowait> <leader>j  :<C-u>CocNext<CR>
" Do default action for previous item
nnoremap <silent><nowait> <leader>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent><nowait> <leader>;  :<C-u>CocListResume<CR>

" Jump to next/previous problem
nmap <silent> [g <Plug>(coc-diagnostic-next)
nmap <silent> ]g <Plug>(coc-diagnostic-prev)

" Prettier (coc-prettier)
vmap <leader><leader>p  <Plug>(coc-format-selected)
nmap <leader><leader>p  <Plug>(coc-format-selected)


" Snippets
"
" Use <C-l> for trigger snippet expand.
imap <C-l> <Plug>(coc-snippets-expand)
" Use <C-j> for select text for visual placeholder of snippet.
vmap <C-j> <Plug>(coc-snippets-select)
" Use <C-j> for jump to next placeholder, it's default of coc.nvim
let g:coc_snippet_next = '<c-j>'
" Use <C-k> for jump to previous placeholder, it's default of coc.nvim
let g:coc_snippet_prev = '<c-k>'
" Use <C-j> for both expand and jump (make expand higher priority.)
imap <C-j> <Plug>(coc-snippets-expand-jump)
" Use <leader>x for convert visual selected code to snippet
xmap <leader>x  <Plug>(coc-convert-snippet)

let g:coc_global_extensions = [
            \ 'coc-yank',
            \ 'coc-json',
            \ 'coc-html',
            \ 'coc-diagnostic',
            \ 'coc-sh',
            \ 'coc-pyright',
            \ 'coc-markdownlint',
            \ 'coc-docker',
            \ 'coc-clangd',
            \ 'coc-css',
            \ 'coc-snippets',
            \ 'coc-yaml',
            \ 'coc-flutter',
            \ 'coc-cmake'
            \ ]
" coc-clangd     --> sudo apt-get install clangd-12
nnoremap <silent> <leader>p  :<C-u>CocList -A --normal yank<cr>

autocmd FileType css setl iskeyword+=-
autocmd FileType scss setl iskeyword+=@-@

" Function to apply CoC configuration dynamically
function! ApplyCocConfig()
  " Check if pylint and mypy are installed
  let pylint_installed = CommandExists('pylint')
  let mypy_installed = CommandExists('mypy')

  " Define CoC settings
  if pylint_installed && mypy_installed
    call coc#config('pyright.disableDiagnostics', v:true)
    call coc#config('python.sortImports.path', 'isort')
    call coc#config('python.linting.enabled', v:true)
    call coc#config('python.linting.flake8Enabled', v:true)
    call coc#config('python.linting.mypyEnabled', v:true)
    call coc#config('python.linting.pylintEnabled', v:true)
  else
    " Disable or reset CoC settings
    call coc#config('pyright.disableDiagnostics', v:false)
    call coc#config('python.sortImports.path', '')
    call coc#config('python.linting.enabled', v:false)
    call coc#config('python.linting.flake8Enabled', v:false)
    call coc#config('python.linting.mypyEnabled', v:false)
    call coc#config('python.linting.pylintEnabled', v:false)
  endif
endfunction

" Automatically apply the configuration when Vim starts
autocmd VimEnter * call ApplyCocConfig()
endif

" ------------------------------- tags ----------------------------------------
"  pycscope 이용
"  find ./ -name "*.[ch]" –print > cscope.files
"  cscope -RUbq
"
"  sed 's/\(.*\)\/$/\1/' .gitignore | sed '/^#/d'
"  ctags -R --exclude='@tags.ignore' -n
"  ------------------------------------------- Set up Guide

" ctags
autocmd BufEnter * exec "set tags=./tags,tags," .. findfile("tags", ".;")

if !has('nvim')
    " cscope
    function! LoadCscope()
        let db = findfile("cscope.out", ".;")
        if (!empty(db))
            let path = strpart(db, 0, match(db, "/cscope.out$"))
            set nocscopeverbose
            exe "cs add " .. db .. " " .. path
            " exe "cs add " .. db
            set cscopeverbose
        elseif $CSCOPE_DB != ""
            cs add $CSCOPE_DB
        endif
    endfunction
    au BufEnter /* call LoadCscope()

    set cscopequickfix=s-,g-,d-,c-,t-,e-,f-,i-,a-
    set csto=1
    set cst

    nmap <Plug>CscopeFindSym :cs find s <C-R>=expand("<cword>")<CR><CR>
    nmap <Plug>CscopeFindDef :cs find g <C-R>=expand("<cword>")<CR><CR>
    nmap <Plug>CscopeFindClr :cs find c <C-R>=expand("<cword>")<CR><CR>
    nmap <Plug>CscopeFindCll :cs find t <C-R>=expand("<cword>")<CR><CR>
    nmap <Plug>CscopeFindTxt :cs find e <C-R>=expand("<cword>")<CR><CR>
    nmap <Plug>CscopeFindGrp :cs find f <C-R>=expand("<cfile>")<CR><CR>
    nmap <Plug>CscopeFindFle :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
    nmap <Plug>CscopeFindInc :cs find d <C-R>=expand("<cword>")<CR><CR>
    nmap <Plug>CscopeFindAsn :cs find a <C-R>=expand("<cword>")<CR><CR>
    nmap <Plug>CscopeFindStc :cs find t struct <C-R>=expand("<cword>")<CR> {<CR>

    " nmap <silent><leader>s <Plug>CscopeFindSym
    " nmap <silent><leader>g <Plug>CscopeFindDef
    " nmap <silent><leader>c <Plug>CscopeFindClr
    " nmap <silent><leader>t <Plug>CscopeFindCll
    " nmap <silent><leader>e <Plug>CscopeFindTxt
    " nmap <silent><leader>f <Plug>CscopeFindGrp
    " nmap <silent><leader>i <Plug>CscopeFindFle
    " nmap <silent><leader>d <Plug>CscopeFindInc
    " nmap <silent><leader>a <Plug>CscopeFindAsn
    " nmap <silent><leader>S <Plug>CscopeFindStc
endif


" -------------------------- fzf(command-line fuzzy finder --------------------
let fzfdir = $HOME .. '/.fzf'
if !empty(fzfdir) && isdirectory(fzfdir)
exec 'set rtp+=' .. fzfdir

" An action can be a reference to a function that processes selected lines
function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val, "lnum": 1 }'))
  copen
  cc
endfunction

let g:fzf_action = {
  \ 'ctrl-q': function('s:build_quickfix_list'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-s': 'split',
  \ 'ctrl-v': 'vsplit' }

" - Popup window (center of the current window)
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6, 'relative': v:true } }

" Customize fzf colors to match your color scheme
" - fzf#wrap translates this to a set of `--color` options
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history
" - History files will be stored in the specified directory
" - When set, CTRL-N and CTRL-P will be bound to 'next-history' and
"   'previous-history' instead of 'down' and 'up'.
let g:fzf_history_dir = '~/.local/share/fzf-history'

nmap <Plug>SearchGitFile
            \ :call fzf#run({'source': 'git ls-files', 'sink': 'e', 'left': '40%'})<CR>

" The query history for this command will be stored as 'ls' inside g:fzf_history_dir.
" The name is ignored if g:fzf_history_dir is not defined.
command! -bang -complete=dir -nargs=? LS
    \ call fzf#run(fzf#wrap('ls', {'source': 'ls', 'dir': <q-args>}))
    " \ call fzf#run(fzf#wrap('ls', {'source': 'ls', 'dir': <q-args>}, <bang>0))

nmap <c-p> :FZF<cr>
endif


" ------------------------- quickui -------------------------------------------
if s:check_installed_plugin('vim-quickui')
function! PopupLines()
    let lines = &lines - 5
    if &lines > 25
        let lines = 25
    endif
    return lines
endfunction

function! PopupColumns()
    let columns = &columns - 20
    if &columns > 120
        let columns = 100
    endif
    return columns
endfunction

function! QuickuiSaveBackup()
    let versionname = quickui#input#open('Enter version name:', 'old')
    call SaveBackup(versionname)
endfunction

" default menu
call quickui#menu#switch('def')

" clear all the menus
call quickui#menu#reset()

call quickui#menu#install("&Files", [
            \ ['&Paste', "set paste!"],
            \ ['--',''],
            \ ['S&croll bar', "MinimapToggle"],
            \ ['&NERD Tree', "NERDTreeToggle"],
            \ ['&Tag Bar', "TagbarToggle"],
            \ ['--',''],
            \ ['Search &Git File', "normal \<Plug>SearchGitFile"],
            \ ['--',''],
            \ ['&Save Session Toggle', "call ObsessionToggle()"],
            \ ['&Delete Session', "call ObsessionDelete()"],
            \ ['--',''],
            \ ['Save Backup', "call QuickuiSaveBackup()"],
            \ ['Delete Swap', "call DeleteSwap()"],
            \ ])

call quickui#menu#install("Co&pilot", [
            \ ['Open &Chat', "CopilotChat"],
            \ ['Open Chat &Explain', "CopilotChatExplain"],
            \ ['Open Chat &Review', "CopilotChatReview"],
            \ ['Open Chat &Fix', "CopilotChatFix"],
            \ ['Open Chat &Optimize', "CopilotChatOptimize"],
            \ ['Open Chat &Docs', "CopilotChatDocs"],
            \ ['Open Chat &Tests', "CopilotChatTests"],
            \ ['Open Chat Co&mmit', "CopilotChatCommit"],
            \ ])

call quickui#menu#install("&Tags", [
            \ ['Function &List', "call quickui#tools#list_function()"],
            \ ['Preview &Tag  <F3>', ":call quickui#tools#preview_tag('')"],
            \ ])

function! TermExit(code)
    echom "terminal exit code: " .. a:code
endfunc

" TODO: ToggleTerm으로 변경
function! OpenShell()
    let opts = {'w':call("PopupColumns",[]),
                \ 'h':call("PopupLines",[]), 'callback':'TermExit'}
    let opts.title = 'Terminal Popup'
    call quickui#terminal#open('bash', opts)
endfunction

function! OpenPython()
    let opts = {'w':call("PopupColumns",[]),
                \ 'h':call("PopupLines",[]), 'callback':'TermExit'}
    let opts.title = 'Python Popup'
    call quickui#terminal#open(
        \ 'bash -c "if [ ! -z $(which ipython) ]; then ipython; else python; fi"',
        \ opts)
endfunction

function! TabRename()
    let previous_tabname = TabooTabName(0)
    let tabname = quickui#input#open('Enter this tab name', previous_tabname)
    execute "TabooRename " .. tabname
endfunction

call quickui#menu#install("&Window", [
            \ ['Tab &New', 'tabnew'],
            \ ['Tab &Close', 'tabclose'],
            \ ['Tab &Rename', 'call TabRename()'],
            \ ['Tab NameReset', 'TabooReset'],
            \ ['--',''],
            \ ['&Shell', 'call OpenShell()'],
            \ ['&Python', 'call OpenPython()'],
            \ ['&Messages', 'Messages'],
            \ ['--',''],
            \ ['Toggle &FoldColumn', 'call ToggleFoldColumn()'],
            \ ['Toggle Cursor High&light', 'call ToggleCursorHighlight()'],
            \ ['Toggle Color R&uler', 'call ToggleRuler()'],
            \ ['--',''],
            \ ['&Buffer Switcher  <F4>', 'call quickui#tools#list_buffer("e")'],
            \ ])

call quickui#menu#install("Coc &Refactor", [
            \ ['Code &Action', "call CocActionAsync('codeAction', visualmode())"],
            \ ['Code Action &Cursor', "normal \<Plug>(coc-codeaction-cursor)"],
            \ ['Code Action &Source', "normal \<Plug>(coc-codeaction-source)"],
            \ ['Code Action S&elected', "normal \<Plug>(coc-codeaction-selected)"],
            \ ['&Rename', "normal \<Plug>(coc-rename)"],
            \ ])

call quickui#menu#install("&CocList", [
            \ ['&Diagnostics', 'CocList diagnostics'],
            \ ['&Extensions', 'CocList extensions'],
            \ ['&Commands', 'CocList commands'],
            \ ['&Outline', 'CocList outline'],
            \ ['&Symbols', 'CocList symbols'],
            \ ['Sni&ppets', 'CocList snippets'],
            \ ])

" register HELP menu with weight 10000
call quickui#menu#install('Help (&?)', [
            \ ["&Index", 'tab help index', ''],
            \ ['Ti&ps', 'tab help tips', ''],
            \ ['--',''],
            \ ["&Tutorial", 'tab help tutor', ''],
            \ ['&Quick Reference', 'tab help quickref', ''],
            \ ['&Summary', 'tab help summary', ''],
            \ ['--',''],
            \ ['&Vim Script', 'tab help eval', ''],
            \ ['&Function List', 'tab help function-list', ''],
            \ ['&Dash Help', 'call asclib#utils#dash_ft(&ft, expand("<cword>"))'],
            \ ], 10000)

" enable to display tips in the cmdline
let g:quickui_show_tip = 1

" hit space twice to open menu
noremap <F1> :call quickui#menu#open()<cr>
call quickui#menu#open('default')

let g:quickui_border_style = 2
let g:quickui_color_scheme = 'gruvbox'

autocmd VimResized * let g:quickui_preview_w = 100
autocmd VimResized * let g:quickui_preview_h = 20

" display vim messages in the textbox
function! DisplayMessages()
    let x = ''
    redir => x
    silent! messages
    redir END
    let x = substitute(x, '[\n\r]\+\%$', '', 'g')
    let content = filter(split(x, "\n"), 'v:key != ""')
    let opts = {"close":"button", "title":"Vim Messages"}
    call quickui#textbox#open(content, opts)
endfunc

command -nargs=0 Messages call DisplayMessages()

let cursor_context_content = [
            \ ['Code Action &Cursor', "normal \<Plug>(coc-codeaction-cursor)"],
            \ ['Code Action &source', "normal \<Plug>(coc-codeaction-source)"],
            \ ['Code Action S&elected', "normal \<Plug>(coc-codeaction-selected)"],
            \ ['&Rename', "normal \<Plug>(coc-rename)"],
            \ ['-'],
            \ ['Find Symbols               \s', "normal \<Plug>CscopeFindSym"],
            \ ['Find Definition            \g', "normal \<Plug>CscopeFindDef"],
            \ ['Find Functions Called by   \c', "normal \<Plug>CscopeFindClr"],
            \ ['Find Functions Calling     \t', "normal \<Plug>CscopeFindCll"],
            \ ['Find Text String           \e', "normal \<Plug>CscopeFindTxt"],
            \ ['Find Egrep Pattern         \f', "normal \<Plug>CscopeFindGrp"],
            \ ['Find File                  \i', "normal \<Plug>CscopeFindFle"],
            \ ['Find Files #including      \d', "normal \<Plug>CscopeFindInc"],
            \ ['Find where value assigned  \a', "normal \<Plug>CscopeFindAsn"],
            \ ['Find Struct                \S', "normal \<Plug>CscopeFindStc"],
            \ ]
" set cursor to the last position
let cursor_context_opts = {'index':g:quickui#context#cursor}
noremap <F2> :call quickui#context#open(cursor_context_content, cursor_context_opts)<cr>

augroup MyQuickfixPreview
    au!
    au FileType qf noremap <silent><buffer> p :call quickui#tools#preview_quickfix()<cr>
augroup END
endif

" --------------------------- minimap -------------------------------------------
if s:check_installed_plugin('minimap.vim')
let g:minimap_auto_start = 0
let g:minimap_auto_start_win_enter = 0
let g:minimap_width = 15
let g:minimap_exec_warning = 0
let g:minimap_highlight_range = 1
let g:minimap_highlight_search = 1
let g:minimap_git_colors = 1
command! Noh execute 'nohlsearch' | call minimap#vim#ClearColorSearch()
cnoreabbrev noh Noh
endif

" --------------------------------- Key Mapping -------------------------------
if s:check_installed_plugin('vim-which-key')
set timeoutlen=500
nnoremap <silent> <leader>      :<c-u>WhichKey '\'<CR>
endif
" Editor
" Should be -n options when making tags
nnoremap <F3> :call quickui#tools#preview_tag('')<cr>
nnoremap <F4> :call quickui#tools#list_buffer("e")<cr>

" buffer
nnoremap <F5> :bp<cr>
nnoremap <F6> :bn<cr>

" tab
nnoremap <F7> :tabp<cr>
nnoremap <F8> :tabn<cr>

" undo remap
nnoremap U <C-r>

" like Shift-enter
inoremap <C-r> <ESC>o

" window
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" highlight
nnoremap <leader><leader>/ :noh<cr>


" -------------------------------- save backup -------------------------------
" 버전별 save 만들기
function! SaveBackup (versionname)
    if a:versionname != ''
        call writefile(getline(1,'$'),
                    \ expand('%:p') .. '.bak.' .. a:versionname)
    endif
endfunction

command! SaveBackup call SaveBackup(input('Enter backup version name: ', strftime("%Y%m%d_%H%M%S")))

" -------------------------- skel file ---------------------------------------
let blog_skel = findfile("_draft/skel.md", ".;")
if (!empty(blog_skel))
    exec 'autocmd BufNewFile *.md  0read ' .. blog_skel
endif

let c_skel = findfile(".skel/skel.c", ".;")
if (!empty(c_skel))
    exec 'autocmd BufNewFile *.c  0read ' .. c_skel
endif

" ----------------------------- undo history ---------------------------------
" undofile directory
let undofile_path = g:local_data_dir . "/undo"
if !isdirectory(undofile_path)
    call mkdir(undofile_path, "p", 0700)
endif
exec 'set undodir=' .. undofile_path
set undofile

" ---------------------------- swap ------------------------------------------
" swap directory
let swapfile_path = g:local_data_dir .. '/temp'
if !isdirectory(swapfile_path)
    call mkdir(swapfile_path, "p", 0700)
endif
exec 'set dir=' .. swapfile_path
exec 'set bdir=' .. swapfile_path

" remove swap
function! DeleteSwap()
    exec "! rm " .. swapname(expand('%'))
endfunction

command! DeleteSwap call DeleteSwap()

" --------------------------- vim local setting -----------------------------
let vimrc_adv = findfile(".vimrc_adv", $HOME)
if (!empty(vimrc_adv))
    exec 'source ' .. vimrc_adv
endif

" ---------------- easy motion --------------------------------
if s:check_installed_plugin('vim-easymotion')
let g:EasyMotion_do_mapping = 0 " Disable default mappings
map <leader>w <Plug>(easymotion-w)
map <leader>W <Plug>(easymotion-W)
map <leader>b <Plug>(easymotion-b)
map <leader>B <Plug>(easymotion-B)
map <leader>e <Plug>(easymotion-e)
map <leader>E <Plug>(easymotion-E)
map <leader>s <Plug>(easymotion-s)
endif

" --------------------------- gitgutter -------------------------------------
if s:check_installed_plugin('vim-gitgutter')
highlight GitGutterAdd    guifg=#009900 ctermfg=82 ctermbg=22
highlight GitGutterChange guifg=#bbbb00 ctermfg=220 ctermbg=130
highlight GitGutterDelete guifg=#ff2222 ctermfg=196 ctermbg=52
endif

" --------------------------- scroll ----------------------------------------
autocmd WinEnter * call AdjustScrolloff()
autocmd WinResized * call AdjustScrolloff()

" scrolloff를 창 높이의 10분의 1로 설정하는 함수
function! AdjustScrolloff()
  let l:win_height = winheight(0)
  let l:scrolloff_value = max([1, l:win_height / 5])
  execute 'setlocal scrolloff=' . float2nr(l:scrolloff_value)
endfunction

" Smooth Scrolling
if s:check_installed_plugin('vim-smoothie')
" 바이트 기준 임계값(예: 2MB)
let g:largefile_threshold = 2 * 1024 * 1024

function! s:HandleLargeFileSmoothie() abort
  " 특수 버퍼/이름 없는 버퍼는 스킵
  if &buftype !=# '' | return | endif
  let l:fname = expand('%:p')
  if empty(l:fname) || !filereadable(l:fname) | return | endif

  let l:size = getfsize(l:fname)
  if l:size >= g:largefile_threshold
    let g:smoothie_enabled = 0

  else
    let g:smoothie_enabled = 1
  endif
endfunction

augroup LargeFileDetect
  autocmd!
  autocmd BufEnter * call s:HandleLargeFileSmoothie()
augroup END

if has('nvim')
    let g:smoothie_update_interval = 10
    let g:smoothie_speed_exponentiation_factor = 0.90
else
    let g:smoothie_update_interval = 10
    let g:smoothie_speed_exponentiation_factor = 0.99
endif
endif

" size(vertical) scroll
nnoremap <M-h> 5zh
nnoremap <M-H> zH
nnoremap <M-l> 5zl
nnoremap <M-L> zL

" --------------------------- context ----------------------------------------
if s:check_installed_plugin('context.vim')
let g:context_highlight_normal = 'Conceal'
let g:context_highlight_border = '<hide>'
let g:context_highlight_tag = '<hide>'
let g:context_delayed_update = 30
endif
