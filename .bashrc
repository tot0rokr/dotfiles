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
    if [ -f ~/.git-prompt.sh ]; then # <== 원래의 PS1 설정을 위한 if 블록에 __git_ps1 변수 값을 끼워넣는 if 문 추가
        #PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$$(__git_ps1 "(Branch:%s)") '
        PS1=$PS1'\[\033[01;35m\]$(__git_ps1 " (%s)")\[\033[00m\] '
    else
        #PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '
        PS1=$PS1' '
    fi

else
    if [ -f ~/.git-prompt.sh ]; then # <== 위와 마찬가지
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

LOCAL_BIN_PATH=$HOME/.local/bin
if [ ! -d "$LOCAL_BIN_PATH" ] ; then
    mkdir -p $LOCAL_BIN_PATH
fi
if ! echo "$PATH" | grep -q "$LOCAL_BIN_PATH"; then
    PATH="$LOCAL_BIN_PATH:$PATH"
fi

make_fake_sudo()
{
cat << EOF > $LOCAL_BIN_PATH/sudo
#!/bin/sh
\$@
EOF
chmod 755 $LOCAL_BIN_PATH/sudo
}

if [ -z $(which sudo) ]; then
    make_fake_sudo
fi

if [ -z $(which lsb_release) ]; then
    sudo apt install -y lsb-release
fi

if [ $(lsb_release -i | awk '{print $3}') == "Ubuntu" ]; then
    if [ -z $(which git) ]; then
        sudo apt install -y git
    fi

    if [ -z $(which curl) ]; then
        sudo apt install -y curl
    fi

    if [ -z $(which wget) ]; then
        sudo apt install -y wget
    fi

    if [ -z $(which gcc) ]; then
        sudo apt install -y gcc
    fi

    if [ -z $(which make) ]; then
        sudo apt install -y make
    fi

    if [ -z $(which python3) ]; then
        sudo apt install -y python3
    fi

    if ! dpkg -l | grep python3-venv 2>&1 > /dev/null; then
        sudo apt install -y python3-venv
    fi

    if [ -z $(which ruby) ]; then
        sudo apt install -y ruby-full
    fi

    if [ -z $(which tmux) ]; then
        sudo apt install -y tmux
    fi

    if [ -z $(which ctags) ]; then
        sudo apt install -y universal-ctags
    fi

    if [ -z $(which cscope) ]; then
        sudo apt install -y cscope
    fi

    if [ -z $(which clangd-12) ]; then
        sudo apt install -y clangd-12
    fi

    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

    if [ "$(command -v nvm)" != "nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    fi

    if [ "$(command -v nvm)" == "nvm" ]; then
        if [ -z $(which npm) ]; then
            nvm install --lts
        fi
    fi

    if [ -f "$HOME/.cargo/env" ]; then
        . "$HOME/.cargo/env"
    fi

    if [ -z $(which cargo) ]; then
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        . "$HOME/.cargo/env"
    fi

    if [ ! -z $(which cargo) ]; then
        if [ -z $(which git-graph) ]; then
            cargo install git-graph
        fi
        if [ -z $(which git-igitt) ]; then
            cargo install git-igitt
        fi
    fi

    if [ -z $(which fd) ]; then
        if [ ! -z $(which fdfind) ]; then
            ln -s $(which fdfind) $LOCAL_BIN_PATH/fd
        else
            sudo apt install -y fd-find && ln -s $(which fdfind) $LOCAL_BIN_PATH/fd
        fi
    fi

    if [ -z $(which bat) ]; then
        if [ ! -z $(which batcat) ]; then
            ln -s $(which batcat) $LOCAL_BIN_PATH/bat
        else
            sudo apt install -y bat && ln -s $(which batcat) $LOCAL_BIN_PATH/bat
        fi
    fi

    # if [ -z $(which vim) ]; then
    #     if [ -z $(which add-apt-repository) ]; then
    #         sudo apt install -y software-properties-common
    #     fi
    #     sudo add-apt-repository ppa:jonathonf/vim
    #     sudo apt update
    #     sudo apt install -y vim
    # fi

    # if [ ! -f ~/.vim/autoload/plug.vim ]; then
    #     curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    #         https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    #     vim +PlugInstall +qall
    # fi

    if [ -z $(which nvim) ]; then
        export PATH="$PATH:/opt/nvim-linux64/bin"
        if [ -z $(which nvim) ]; then
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
            sudo rm -rf /opt/nvim
            sudo tar -C /opt -xzf nvim-linux64.tar.gz
            rm nvim-linux64.tar.gz
        fi
    fi

    if [ ! -f ~/.local/share/nvim/site/autoload/plug.vim ]; then
        curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        nvim +PlugInstall +qall
    fi

    if [ -z $(which rg) ]; then
        sudo apt install -y ripgrep
    fi

    if [ -z $(which jq) ]; then
        sudo apt install -y jq
    fi

    if [ -z $(which delta) ]; then
        delta_ver=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name')
        wget -O git-delta.deb "https://github.com/dandavison/delta/releases/download/${delta_ver}/git-delta_${delta_ver}_amd64.deb"
        sudo dpkg -i git-delta.deb
        rm git-delta.deb
    fi

fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
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

cd ~

[ -f ~/.fzf.bash ] && source ~/.fzf.bash


export PROMPT_COMMAND="history -a; history -n"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
