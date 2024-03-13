" Vim Set Up
" Language: vim-script
" Author:   Junho Lee (TOT0Ro)

let g:vimdir = $HOME .. '/.vim'


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
Plug 'ctrlpvim/ctrlp.vim'

" thema (schema)
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
let g:NERDSpaceDelims=1

" ctags
Plug 'xolox/vim-misc'

" easymotion
Plug 'easymotion/vim-easymotion'

" argument movable
Plug 'peterrincker/vim-argumentative'

" git
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'
highlight GitGutterAdd    guifg=#009900 ctermfg=82 ctermbg=22
highlight GitGutterChange guifg=#bbbb00 ctermfg=220 ctermbg=130
highlight GitGutterDelete guifg=#ff2222 ctermfg=196 ctermbg=52
" git conlict. required tpope/vim-fugitive
Plug 'christoomey/vim-conflicted'


" line orient
" Plug 'tommcdo/vim-lion'

" MarkDown
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && npx --yes yarn install' }
nmap <leader><leader>m <Plug>MarkdownPreviewToggle

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
Plug 'nathanaelkane/vim-indent-guides'
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd ctermbg=235
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=235
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
let g:indent_guides_default_mapping = 0

" docstring
" Need to make install
" $ cd ~/.vim/bundle/vim-pydocstring
" $ make install
Plug 'heavenshell/vim-pydocstring', { 'do': 'make install', 'for': 'python' }
let g:pydocstring_formatter = 'google'
let g:pydocstring_ignore_init = 1
let g:pydocstring_enable_mapping = 0

" quickui
Plug 'skywind3000/vim-quickui'

" fzf
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }

" Shell
Plug 'Shougo/deol.nvim'

" Tab
Plug 'gcmt/taboo.vim'
set sessionoptions+=tabpages,globals
let g:taboo_tab_format=' %f%m%U '
let g:taboo_renamed_tab_format=' <%l>%m%U '
let g:taboo_modified_tab_flag='+'

" Session save
Plug 'tpope/vim-obsession'
let g:obsession_no_bufenter = 1

" Snippets
" Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'

" Flutter
Plug 'dart-lang/dart-vim-plugin'
let g:dart_html_in_string = v:true
let g:dart_style_guide = 2
let g:dart_format_on_save = v:true
" Plug 'natebosch/vim-lsc'
" Plug 'natebosch/vim-lsc-dart'
" let g:lsc_auto_map = v:true


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

set background=dark
" set t_Co=16
set t_Co=256
set autoread
autocmd CursorHold * :checktime
set hlsearch


set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent
set textwidth=80
set formatoptions-=t

autocmd FileType c setlocal ts=4 sts=4 sw=4 noexpandtab cc=+0
autocmd FileType cpp setlocal ts=4 sts=4 sw=4 expandtab cc=+0
autocmd FileType vim setlocal ts=4 sts=4 sw=4 expandtab cc=+0
autocmd FileType python setlocal ts=4 sts=4 sw=4 expandtab textwidth=88 cc=+0
autocmd FileType markdown setlocal ts=4 sts=4 sw=4 expandtab textwidth=100 cc=+0
autocmd FileType html setlocal ts=4 sts=4 sw=4 expandtab textwidth=100 cc=+0

" --------------------------- COMMIT_EDITMSG ---------------------------------
autocmd BufEnter COMMIT_EDITMSG set textwidth=72 cc=+0 formatoptions+=t
autocmd BufEnter COMMIT_EDITMSG highlight CommitEditor ctermbg=105 cterm=None
autocmd BufEnter COMMIT_EDITMSG match CommitEditor '\%1l\%50v'

" ------------------------- 라인 끝 공백 highlight --------------------------
highlight ExtraWhitespace ctermbg=88
match ExtraWhitespace /\s\+$/
autocmd WinEnter * match ExtraWhitespace /\s\+$/
autocmd WinLeave * call clearmatches()


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
nnoremap <space> za
vnoremap <space> zf
highlight FoldColumn ctermfg=3 ctermbg=none
highlight Folded ctermfg=245 ctermbg=none

let foldfiles = {
            \ "python": g:vimdir .. "/python_fold.vim"
            \}
let python_fold = findfile(foldfiles.python)
if !empty(python_fold)
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

hi CursorLine ctermbg=237 cterm=None
hi CursorColumn ctermbg=237 cterm=None
hi ColorColumn ctermbg=105 cterm=None
" syntax enable
" set wmnu
" set nu

" ------------------------------- diff ----------------------------------------

" diff
highlight DiffAdd       ctermbg=22
highlight DiffChange    ctermbg=54
highlight DiffDelete    ctermbg=88
highlight DiffText      ctermbg=237

" --------------------------- statusbar/ airline ------------------------------
set laststatus=2 " vim-airline을 위해 상태바 2줄
if 1
    let g:airline_powerline_fonts = 1
    let g:airline#extensions#tabline#enabled = 1
    let g:airline#extensions#tabline#left_sep = ''
    let g:airline#extensions#tabline#left_alt_sep = ''
    let g:airline#extensions#tabline#right_sep = ''
    let g:airline#extensions#tabline#right_alt_sep = ''
    " let g:airline#extensions#tabline#left_sep = ' '
    " let g:airline#extensions#tabline#left_alt_sep = ' '
    " let g:airline#extensions#tabline#right_sep = ' '
    " let g:airline#extensions#tabline#right_alt_sep = ' '
    let g:airline#extensions#tabline#formatter = 'unique_tail'
    let g:airline#extensions#tabline#tab_nr_type = 1
    let g:airline#extensions#tabline#show_tab_nr = 1
    let g:airline#extensions#tabline#tabtitle_formatter = 'TabTitleFormatter'
    function TabTitleFormatter(n)
        return TabooTabTitle(0)
    endfunction

    let g:airline_theme='serene'

    if !exists('g:airline_symbols')
        let g:airline_symbols = {}
    endif
    let g:airline_left_alt_sep = ''
    let g:airline_right_alt_sep = ''
    let g:airline_left_sep = ''
    let g:airline_right_sep = ''
    let g:airline_symbols.paste = ' '
    " let g:airline_left_sep = ' '
    " let g:airline_right_sep = ' '
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

" -------------------------- coc ----------------------------------------------
if 1
    inoremap <silent><expr> <TAB>
          \ coc#pum#visible() ? coc#pum#next(1) :
          \ CheckBackspace() ? "\<TAB>" :
          \ coc#refresh()
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
endif

" ------------------------------- Obsession ----------------------------------
" Obsession status
" - 0: disable
" - 1: enable
" - 2: not use
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

let g:obsession_dir = g:vimdir .. '/obsession'
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

nmap <silent><leader>s <Plug>CscopeFindSym
nmap <silent><leader>g <Plug>CscopeFindDef
nmap <silent><leader>c <Plug>CscopeFindClr
nmap <silent><leader>t <Plug>CscopeFindCll
nmap <silent><leader>e <Plug>CscopeFindTxt
nmap <silent><leader>f <Plug>CscopeFindGrp
nmap <silent><leader>i <Plug>CscopeFindFle
nmap <silent><leader>d <Plug>CscopeFindInc
nmap <silent><leader>a <Plug>CscopeFindAsn
nmap <silent><leader>S <Plug>CscopeFindStc


" -------------------------- fzf(command-line fuzzy finder --------------------
let fzfdir = $HOME .. '/.fzf'
exec 'set rtp+=' .. fzfdir

let g:fzf_action = {
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
    \ call fzf#run(fzf#wrap('ls', {'source': 'ls', 'dir': <q-args>}, <bang>0))


" ------------------------- quickui -------------------------------------------
if 1
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

    call quickui#menu#install("&Tags", [
                \ ['Function &List', "call quickui#tools#list_function()"],
                \ ['Preview &Tag  <F3>', ":call quickui#tools#preview_tag('')"],
                \ ])

    function! TermExit(code)
        echom "terminal exit code: " .. a:code
    endfunc

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
                \ ['Buffer &Delete', 'bdelete'],
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
                \ ['-'],
                \ ['Code Action &Cursor', "normal \<Plug>(coc-codeaction-cursor)"],
                \ ['Code Action &source', "normal \<Plug>(coc-codeaction-source)"],
                \ ['Code Action S&elected', "normal \<Plug>(coc-codeaction-selected)"],
                \ ['&Rename', "normal \<Plug>(coc-rename)"],
                \ ]
    " set cursor to the last position
    let cursor_context_opts = {'index':g:quickui#context#cursor}
    noremap <F2> :call quickui#context#open(cursor_context_content, cursor_context_opts)<cr>

    augroup MyQuickfixPreview
        au!
        au FileType qf noremap <silent><buffer> p :call quickui#tools#preview_quickfix()<cr>
    augroup END
endif

" --------------------------------- Key Mapping -------------------------------
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
let undofile_path = g:vimdir . "/undo"
if !isdirectory(undofile_path)
    call mkdir(undofile_path, "p", 0700)
endif
exec 'set undodir=' .. undofile_path
set undofile

" ---------------------------- swap ------------------------------------------
" swap directory
let swapfile_path = g:vimdir .. '/temp'
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


" ---------------------------- Keyboard Layout ------------------------------
let s:qwerty = [
      \ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p',
      \ 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';',
      \ 'z', 'x', 'c', 'v', 'b', 'n', 'm',
      \ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P',
      \ 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':',
      \ 'Z', 'X', 'C', 'V', 'B', 'N', 'M']

let s:workman = [
      \ 'q', 'd', 'r', 'w', 'b', 'j', 'f', 'u', 'p', ';',
      \ 'a', 's', 'h', 't', 'g', 'y', 'n', 'e', 'o', 'i',
      \ 'z', 'x', 'm', 'c', 'v', 'k', 'l',
      \ 'Q', 'D', 'R', 'W', 'B', 'J', 'F', 'U', 'P', ':',
      \ 'A', 'S', 'H', 'T', 'G', 'Y', 'N', 'E', 'O', 'I',
      \ 'Z', 'X', 'M', 'C', 'V', 'K', 'L' ]

function! WorkmanLayout()
    for [workman_key, qwerty_key] in map(copy(s:workman), '[v:val, s:qwerty[v:key]]')
        execute "noremap!" qwerty_key workman_key
    endfor
endfunction

command! WorkmanLayout call WorkmanLayout()

function! QwertyLayout()
    for [workman_key, qwerty_key] in map(copy(s:workman), '[v:val, s:qwerty[v:key]]')
        execute "unmap!" qwerty_key
    endfor
endfunction

command! QwertyLayout call QwertyLayout()
