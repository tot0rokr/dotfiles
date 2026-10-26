" A01/A20: writes the vim state the checks look at to $T_RESULT as key=value
" lines, then quits. Sourced with `vim -S`, after the vimrc and the plugins.
let s:out = []
call add(s:out, 'patch-9.1.0327=' .. has('patch-9.1.0327'))
call add(s:out, 'initvim=' .. $INITVIM)
call add(s:out, 'plug_home=' .. get(g:, 'plug_home', ''))
call add(s:out, 'plugs=' .. len(get(g:, 'plugs', {})))
let s:missing = filter(values(get(g:, 'plugs', {})), '!isdirectory(v:val.dir)')
call add(s:out, 'plugs_missing=' .. join(map(s:missing, 'v:val.dir'), ' '))
call add(s:out, 'undodir=' .. &undodir)
call add(s:out, 'directory=' .. &directory)
call add(s:out, 'backupdir=' .. &backupdir)
call add(s:out, 'viminfofile=' .. &viminfofile)
call add(s:out, 'fzf_run=' .. exists('*fzf#run'))
call add(s:out, 'ls_cmd=' .. exists(':LS'))
call add(s:out, 'conflicted=' .. exists(':Conflicted'))
" Written before the coc call too, in case coc is missing and that call fails.
call writefile(s:out, $T_RESULT)
call add(s:out, 'coc_config_home=' .. coc#util#get_config_home())
call writefile(s:out, $T_RESULT)
qa!
