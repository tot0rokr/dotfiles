# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

alias vi='vim'
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
alias cat="bat"

alias cd..='cd ..'
