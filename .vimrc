" Vim Set Up
" Language: vim-script
" Author:   Junho Lee (TOT0Ro)
"
" Vim only. Neovim starts from ~/.config/nvim/init.vim; both editors read the
" shared plugin list (~/.vim/plugins.vim) and settings (~/.vim/common.vim).

let g:local_data_dir = $HOME .. '/.vim'

" -------------------------------- Plugin -----------------------------------

call plug#begin()
" The default plugin directory will be as follows:
"   - Vim (Linux/macOS): '~/.vim/plugged'
"   - Vim (Windows): '~/vimfiles/plugged'
"   - Neovim (Linux/macOS/Windows): stdpath('data') . '/plugged'
" You can specify a custom plugin directory by passing it as the argument
"   - e.g. `call plug#begin('~/.vim/plugged')`
"   - Avoid using standard Vim directory names like 'plugin'

source ~/.vim/plugins.vim

" indent guide
Plug 'nathanaelkane/vim-indent-guides'

" Shell
Plug 'Shougo/deol.nvim'

" Scrolling
Plug 'tot0rokr/vim-smoothie'

" Initialize plugin system
" - Automatically executes `filetype plugin indent on` and `syntax enable`.
call plug#end()
" You can revert the settings after the call like so:
"   filetype indent off   " Disable file-type-specific indentation
"   syntax off            " Disable syntax highlighting

" g:plugs is missing when plug.vim is not installed; common.vim then runs
" without plugins instead of failing on every PluginInstalled()
let g:plugin_dirs = map(copy(get(g:, 'plugs', {})), 'v:val.dir')

source ~/.vim/common.vim

" ------------------------------- Indent -----------------------------------
if PluginInstalled('vim-indent-guides')
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd ctermbg=235 guibg=#262626
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=237 guibg=#3a3a3a
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
let g:indent_guides_default_mapping = 0
endif

" -------------------------- coc ----------------------------------------------
" Use <c-space> to trigger completion; Vim receives it as <c-@>
if PluginInstalled('coc.nvim')
inoremap <silent><expr> <c-@> coc#refresh()
endif

" ------------------------------- cscope -------------------------------------
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

" -------------------------- fzf ----------------------------------------------
if isdirectory($HOME .. '/.fzf')
nmap <c-p> :Files<cr>
nmap <M-p> :GFiles<cr>
nnoremap <F5> :Buffers<cr>
nnoremap <F7> :Rg<cr>
nnoremap <S-F7> :RG<cr>
nnoremap <F8> :History:<cr>
nnoremap <F9> :Blines<cr>
nnoremap <S-F9> :Lines<cr>
nnoremap <F10> :BCommits<cr>
nnoremap <S-F10> :Commits<cr>
endif

" --------------------------- scroll ----------------------------------------
" Smooth Scrolling
" Neovim uses smoothie.nvim, whose max_filesize (lua/init.lua) does this.
if PluginInstalled('vim-smoothie')
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

let g:smoothie_update_interval = 10
let g:smoothie_speed_exponentiation_factor = 0.99
endif

" ------------------------------------------------------------------------------
" plug#end() put the plugins on 'runtimepath'; run the code in common.vim that
" calls their functions.
if exists('#User#PluginsReady')
    doautocmd <nomodeline> User PluginsReady
endif
