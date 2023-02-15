# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth:erasedups

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=100000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi


#For Git prompt
if [ -f ~/.git-prompt.sh ]; then
    source ~/.git-prompt.sh
fi

if [ "$color_prompt" = yes ]; then
    if [ -f ~/.git-prompt.sh ]; then # Add an if statement to insert the value of the __git_ps1 variable into the if block for setting up the original PS1
        #PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$$(__git_ps1 "(Branch:%s)") '
        PS1=$PS1'\[\033[01;35m\]$(__git_ps1 " (%s)")\[\033[00m\] '
    else
        #PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '
        PS1=$PS1' '
    fi

else
    if [ -f ~/.git-prompt.sh ]; then # <== same as above
        PS1='${debian_chroot:+($debian_chroot)}\u:\W\$$(__git_ps1 "(Branch:%s)") '
    else
        PS1='${debian_chroot:+($debian_chroot)}\u:\W\$ '
    fi
fi

if [ -f ~/.git-completion.bash ]; then
    source ~/.git-completion.bash
fi

unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'


# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [ $(lsb_release -i | awk '{print $3}') == "Ubuntu" ]; then
    if [ -z $(which curl) ]; then
        sudo apt-get install -y curl
    fi

    if [ -z $(which wget) ]; then
        sudo apt-get install -y wget
    fi

    if [ -z $(which git) ]; then
        sudo apt-get install -y git
    fi

    if [ -z $(which gcc) ]; then
        sudo apt-get install -y gcc
    fi

    if [ -z $(which make) ]; then
        sudo apt-get install -y make
    fi

    if [ -z $(which python3) ]; then
        sudo apt-get install -y python3
    fi

    if [ -z $(which tmux) ]; then
        sudo apt-get install -y tmux
    fi

    if [ -z $(which vim) ]; then
        sudo add-apt-repository ppa:jonathonf/vim
        sudo apt update
        sudo apt install -y vim
        git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
        vim +PluginInstall +qall
    fi

    if [ -z $(which ctags) ]; then
        sudo apt-get install -y ctags
    fi

    if [ -z $(which cscope) ]; then
        sudo apt-get install -y cscope
    fi

    if [ -z $(which fd) ]; then
        if [ ! -z $(which fdfind) ]; then
            ln -s $(which fdfind) ~/.local/bin/fd
        else
            sudo apt-get install -y fd-find
            ln -s $(which fdfind) ~/.local/bin/fd
        fi
    fi

    if [ -z $(which bat) ]; then
        if [ ! -z $(which batcat) ]; then
            ln -s $(which batcat) ~/.local/bin/bat
        else
            sudo apt-get install -y bat
            ln -s $(which batcat) ~/.local/bin/bat
        fi
    fi
fi

# Alias definitions.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# fzf setting
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

cd ~
