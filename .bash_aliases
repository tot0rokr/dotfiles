# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ ! -z $(which z) ]; then
    alias cd='z'
fi

if [ ! -z $(which bat) ]; then
    alias cat="bat"
fi

if [ ! -z $(which dust) ]; then
    alias du="dust"
fi

if [ ! -z $(which lazydocker) ]; then
    alias lzd="lazydocker"
fi

if [ ! -z $(which eza) ]; then
    alias ls="eza"
fi

if [ ! -z $(which tldr) ]; then
    alias man="tldr"
fi

if [ ! -z $(which difft) ]; then
    alias diff="difft"
fi

if [ ! -z $(which up) ]; then
    alias up="lshw |& up"
fi

alias vi='vim'
alias vim='nvim'
alias la='ls -A'
alias l='ls -CF'
alias lla='ls -AlF'
alias ll='ls -lF'
alias l.='ls -AF -I[^.]*'
alias ll.='ls -AlF -I[^.]*'
alias jb='jobs'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I'
alias tmux='tmux -2'
alias ipython="ipython --TerminalInteractiveShell.editing_mode=vi"
alias fzf="fzf --preview 'bat --color=always {}' --preview-window '~3'"
alias rgmd="rg --max-depth"

alias cd-='cd -'
alias cd.='cd ..'
alias cd..='cd ../..'
alias cd...='cd ../../..'
alias cd....='cd ../../../..'
alias cd.....='cd ../../../../..'
