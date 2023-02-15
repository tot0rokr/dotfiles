" Vim Set Up
" Language: vim-script
" Author:   Junho Lee (TOT0Ro)
" Last Change:  2023 Feb 14
" Version:  1.0

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin('~/.vim/bundle')

Plugin 'VundleVim/Vundle.vim'

Plugin 'tpope/vim-sensible' " normal setup

Plugin 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }

" File finder
Plugin 'ctrlpvim/ctrlp.vim'

" thema (schema)
"Plugin 'junegunn/seoul256.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'edkolev/tmuxline.vim'

" keyword tag bar
Plugin 'majutsushi/tagbar'

" auto completion
Plugin 'neoclide/coc.nvim', {'branch': 'release'}

" write comment
Plugin 'scrooloose/nerdcommenter'
let g:NERDSpaceDelims=1

" ctags
Plugin 'xolox/vim-misc'

" easymotion
Plugin 'Lokaltog/vim-easymotion'

" argument movable
Plugin 'peterrincker/vim-argumentative'

" git
Plugin 'airblade/vim-gitgutter'
Plugin 'tpope/vim-fugitive'
highlight GitGutterAdd    guifg=#009900 ctermfg=82 ctermbg=22
highlight GitGutterChange guifg=#bbbb00 ctermfg=220 ctermbg=130
highlight GitGutterDelete guifg=#ff2222 ctermfg=196 ctermbg=52
" git conlict. required tpope/vim-fugitive
Plugin 'christoomey/vim-conflicted'


" line orient
" Plugin 'tommcdo/vim-lion'

" MarkDown
Plugin 'iamcco/markdown-preview.nvim'
nmap <leader><leader>m <Plug>MarkdownPreviewToggle

" code break game
Plugin 'johngrib/vim-game-code-break'

" REST API
Plugin 'diepm/vim-rest-console'

" diff character
" Plugin 'vim-scripts/diffchar.vim'

" > Plugin ALE
" Plugin 'dense-analysis/ale'
" > let g:ale_completion_enabled = 1
" > set omnifunc=ale#completion#OmniFunc
" let g:ale_lint_on_text_changed = 'never'
" let g:ale_lint_on_enter = 0

" Icon
Plugin 'ryanoasis/vim-devicons'

" swap recovery
Plugin 'chrisbra/Recover.vim'

" indent guide
Plugin 'nathanaelkane/vim-indent-guides'
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd ctermbg=235
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=235
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
let g:indent_guides_default_mapping = 0

" docstring
Plugin 'heavenshell/vim-pydocstring', { 'do': 'make install', 'for': 'python' }
let g:pydocstring_formatter = 'google'
let g:pydocstring_ignore_init = 1
let g:pydocstring_enable_mapping = 0

" quickui
Plugin 'skywind3000/vim-quickui'

" fzf
Plugin 'junegunn/fzf'

call vundle#end()

filetype plugin indent on

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
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()


" ---------------------------------- folding ---------------------------------
set foldmethod=manual
set foldnestmax=2
set foldlevel=1
set foldcolumn=0
exec 'set fillchars=fold:\ '

function! MyFoldText()
    let nl = v:foldend - v:foldstart + 1
    let txt = getline(v:foldstart) . ' --- length ' . nl . ' '
    return txt
endfunction
set foldtext=MyFoldText()
nnoremap <space> za
vnoremap <space> zf
highlight FoldColumn ctermfg=3 ctermbg=none
highlight Folded ctermfg=245 ctermbg=none

let foldfiles = {
            \ "python": "~/.vim/python_fold.vim"
            \}
let python_fold = findfile(foldfiles.python)
if !empty(python_fold)
    exec 'autocmd FileType python source ' .. python_fold
endif


" -------------------------------- quick fix --------------------------------
function! OpenQuickfixWindow()
    let length = len(getqflist())
    if length > 10
        let length = 10
    endif
    if length > 1
        exec "copen" . length
    else
        exec "cclose"
    endif
endfunction

autocmd QuickFixCmdPost * :call OpenQuickfixWindow()
autocmd BufReadPost quickfix setlocal modifiable
		\ | silent exec 'g/^/s//\=line(".")." "/'
		\ | setlocal nomodifiable


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

" ------------------------------- color columns ------------------------------

autocmd BufReadPre * let b:colorcolumns = &cc
function! ToggleColorColumn ()
    if &cc != '0'
        let b:colorcolumns = &cc
        exec 'set cc=0'
    else
        if !exists('b:colorcolumns')
            let b:colorcolumns = 0
        endif
        exec 'set cc=' . b:colorcolumns
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
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ''
let g:airline#extensions#tabline#left_alt_sep = ''
let g:airline#extensions#tabline#right_sep = ''
let g:airline#extensions#tabline#right_alt_sep = ''
let g:airline#extensions#tabline#formatter = 'unique_tail'
let g:airline_theme='serene'

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
let g:airline_left_sep = ''
let g:airline_right_sep = ''
let g:airline_symbols.paste = 'ρ'

function! GetWindowNumber()
    return ' Ш' . tabpagewinnr(tabpagenr())
endfunction
function! GetFoldLevel()
    return foldlevel(line('.')) > 0 ? ' Ɀ' . foldlevel(line('.')) : ''
endfunction
call airline#parts#define(
       \ 'foldlevel', {'function': 'GetFoldLevel', 'accents': 'bold'})
call airline#parts#define(
       \ 'windownumber', {'function': 'GetWindowNumber', 'accents': 'bold'})
let g:airline_section_z = airline#section#create(
       \ ['%p%%', 'linenr', 'maxlinenr', 'colnr', 'foldlevel', 'windownumber'])

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
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

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
autocmd CursorHold * silent call CocActionAsync('highlight')

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

" CocInstall coc-json
" CocInstall cmake
" CocInstall markdownlint
" CocInstall coc-jedi
" CocInstall coc-yank
" CocInstall coc-docker
" CocInstall coc-clangd
" CocInstall coc-diagnostic
nnoremap <silent> <leader>p  :<C-u>CocList -A --normal yank<cr>


" ------------------------------- tags ----------------------------------------
"  pycscope 이용
"  find ./ -name "*.[ch]" –print > cscope.files
"  cscope -RUbq
"
"  sed 's/\(.*\)\/$/\1/' .gitignore | sed '/^#/d'
"  ctags -R --exclude='@tags.ignore' -n
"  ------------------------------------------- Set up Guide

" ctags
autocmd BufEnter * exec "set tags=./tags,tags," . findfile("tags", ".;")

" cscope
function! LoadCscope()
        let db = findfile("cscope.out", ".;")
        if (!empty(db))
                let path = strpart(db, 0, match(db, "/cscope.out$"))
                set nocscopeverbose
                exe "cs add " . db . " " . path
                " exe "cs add " . db
                set cscopeverbose
        elseif $CSCOPE_DB != ""
                cs add $CSCOPE_DB
        endif
endfunction
au BufEnter /* call LoadCscope()
set cscopequickfix=s-,g-,d-,c-,t-,e-,f-,i-,a-
set csto=0
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

nnoremap <silent><leader>s <Plug>CscopeFindSym
nnoremap <silent><leader>g <Plug>CscopeFindDef
nnoremap <silent><leader>c <Plug>CscopeFindClr
nnoremap <silent><leader>t <Plug>CscopeFindCll
nnoremap <silent><leader>e <Plug>CscopeFindTxt
nnoremap <silent><leader>f <Plug>CscopeFindGrp
nnoremap <silent><leader>i <Plug>CscopeFindFle
nnoremap <silent><leader>d <Plug>CscopeFindInc
nnoremap <silent><leader>a <Plug>CscopeFindAsn
nnoremap <silent><leader>S <Plug>CscopeFindStc


" -------------------------- fzf(command-line fuzzy finder --------------------
let fzfdir = $HOME . '/.fzf'
exec 'set rtp+=' . fzfdir

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


" default menu
call quickui#menu#switch('def')

" clear all the menus
call quickui#menu#reset()

call quickui#menu#install("&Files", [
            \ ['&NERD Tree', "NERDTreeToggle"],
            \ ['&Tag &Bar', "TagbarToggle"],
            \ ['--',''],
            \ ['Search Git &File', "normal \<Plug>SearchGitFile"],
            \ ['--',''],
            \ ['Save &Backup', "call SaveBackup()"],
            \ ['Delete &Swap', "call DeleteSwap()"],
            \ ])

call quickui#menu#install("&Tags", [
            \ ['Function &List', "call quickui#tools#list_function()"],
            \ ['Preview &Tag  <F3>', ":call quickui#tools#preview_tag('')"],
            \ ])

call quickui#menu#install("Coc &Refactor", [
            \ ['Code &Action', "call CocActionAsync('codeAction', visualmode())"],
            \ ['Code Action &Cursor', "normal \<Plug>(coc-codeaction-cursor)"],
            \ ['Code Action &source', "normal \<Plug>(coc-codeaction-source)"],
            \ ['&Rename', "normal \<Plug>(coc-rename)"],
            \ ])

call quickui#menu#install("&CocList", [
            \ ['&Diagnostics', 'CocList diagnostics'],
            \ ['&Extensions', 'CocList extensions'],
            \ ['&Commands', 'CocList commands'],
            \ ['&Outline', 'CocList outline'],
            \ ['&Symbols', 'CocList symbols'],
            \ ])

function! TermExit(code)
    echom "terminal exit code: ". a:code
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
	call quickui#terminal#open('python', opts)
endfunction

call quickui#menu#install("&Window", [
            \ ['&Buffer Switcher  <F4>', 'call quickui#tools#list_buffer("e")'],
            \ ['Buffer &Delete', 'bdelete'],
            \ ['Tab &New', 'tabnew'],
            \ ['Tab &Close', 'tabclose'],
            \ ['--',''],
            \ ['&Shell', 'call OpenShell()'],
            \ ['&Python', 'call OpenPython()'],
            \ ['--',''],
            \ ['Toggle Cursor High&light', 'call ToggleCursorHighlight()'],
            \ ['Toggle Color &TextWidth', 'call ToggleColorColumn()'],
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

command -nargs=0 Msg call DisplayMessages()

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
            \ ['&Rename', "normal \<Plug>(coc-rename)"],
            \ ]
" set cursor to the last position
let cursor_context_opts = {'index':g:quickui#context#cursor}
noremap <F2> :call quickui#context#open(cursor_context_content, cursor_context_opts)<cr>

augroup MyQuickfixPreview
    au!
    au FileType qf noremap <silent><buffer> p :call quickui#tools#preview_quickfix()<cr>
augroup END

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
function! SaveBackup ()
    let versionname = quickui#input#open('Enter version name:', 'unknown')
    if versionname != ''
        call writefile(getline(1,'$'),
                    \ getcwd('%') . '/' . bufname('%') . '.bak_' . versionname)
    endif
endfunction


" -------------------------- skel file ---------------------------------------
let blog_skel = findfile("_draft/skel.md", ".;")
if (!empty(blog_skel))
    exec 'autocmd BufNewFile *.md  0read ' . blog_skel
endif

let c_skel = findfile(".skel/skel.c", ".;")
if (!empty(c_skel))
    exec 'autocmd BufNewFile *.c  0read ' . c_skel . ' | /\/\/TODO/'
endif

" ----------------------------- undo history ---------------------------------
" undofile directory
let undofile_path = $HOME . "/.vim/undo"
if !isdirectory(undofile_path)
    call mkdir(undofile_path, "p", 0700)
endif
exec 'set undodir=' . undofile_path
set undofile

" ---------------------------- swap ------------------------------------------
" swap directory
let swapfile_path = $HOME . '/.vim/temp'
if !isdirectory(swapfile_path)
    call mkdir(swapfile_path, "p", 0700)
endif
exec 'set dir=' . swapfile_path
exec 'set bdir=' . swapfile_path

" remove swap
function! DeleteSwap()
    exec "! rm " . &dir . "/" . @% . ".swp"
endfunction

" --------------------------- vim local setting -----------------------------
let vimrc_adv = findfile("~/.vimrc_adv")
if (!empty(vimrc_adv))
    exec 'source ' . vimrc_adv
endif
