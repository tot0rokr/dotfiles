# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

ARCHITECTURE=$(dpkg --print-architecture)

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
    xterm-kitty|xterm-color|*-256color) color_prompt=yes;;
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


# Tab completion:
bind 'TAB:menu-complete' # 리스트업
bind '"\e[Z":menu-complete-backward' # 순환

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
        echo "Install git"
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

    if [ -z $(which lazygit) ]; then
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit -D -t /usr/local/bin/
        rm layzgit.tar.gz lazygit
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

    if [ ${ARCHITECTURE} == "amd64" ]; then
        NVIM_ARCH="x86_64"
    fi

    if [ -z $(which nvim) ]; then
        export PATH="$PATH:/opt/nvim-linux-${NVIM_ARCH}/bin"
        if [ -z $(which nvim) ]; then
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz
            sudo rm -rf /opt/nvim
            sudo tar -C /opt -xzf nvim-linux-${NVIM_ARCH}.tar.gz
            rm nvim-linux-${NVIM_ARCH}.tar.gz
        fi
    fi

    if [ ! -f ~/.local/share/nvim/site/autoload/plug.vim ]; then
        curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        nvim +PlugInstall +qall
        pip3 install --user pynvim
    fi

    if [ -z $(which rg) ]; then
        sudo apt install -y ripgrep
    fi

    if [ -z $(which jq) ]; then
        sudo apt install -y jq
    fi

    if [ -z $(which delta) ]; then

        delta_ver=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name')
        wget -O git-delta.deb "https://github.com/dandavison/delta/releases/download/${delta_ver}/git-delta_${delta_ver}_${ARCHITECTURE}.deb"
        sudo dpkg -i git-delta.deb
        rm git-delta.deb
    fi

    if [ -z $(which wezterm) ]; then
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
        echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
        sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
        sudo apt update
        sudo apt install wezterm
    fi

    if [ -z $(which lazydocker) ]; then
        echo "Install lazydocker"
        curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
    fi

    if [ -z $(which zoxide) ]; then
        echo "Install zoxide"
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
        #sudo apt install -y zoxide
    fi

    if [ -z $(which nnn) ]; then
        sudo apt install -y nnn
    fi

    if [ -z $(which gdu) ]; then
        sudo apt install -y gdu
    fi

    if [ -z $(which dust) ]; then
        sudo snap install dust
    fi

    if [ -z $(which eza) ]; then
        echo "Install eza"
        sudo apt update
        sudo apt install -y gpg
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt update
        sudo apt install -y eza
    fi

    if [ -z $(which starship) ]; then
        echo "Install starship"
        sudo curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi

    if [ ! -f ~/.local/bin/choose ]; then
        echo "Install choose"
        git clone https://github.com/theryangeary/choose.git
        cd choose
        cargo build --release
        install target/release/choose ~/.local/bin/
        cd ..
        rm -r choose
    fi

    if [ -z $(which hyperfine) ]; then
        echo "Install hyperfine"
        sudo apt install hyperfine
    fi

    if [ -z $(which difft) ]; then
        echo "Install difftastic"
        cargo install --locked difftastic
    fi

    if [ -z $(which tldr) ]; then
        echo "Install tldr"
        cargo install tealdeer
        tldr --seed-config
        tldr -u
    fi

    if [ ! -f ~/.local/bin/up ]; then
        echo "Install up"
        wget https://github.com/akavel/up/releases/latest/download/up
        chmod a+x up
        mv up ~/.local/bin
    fi

fi

# Safe X11 DISPLAY setup for SSH, even inside tmux
if [[ -n "$SSH_CONNECTION" ]]; then
  export DISPLAY=$(echo $SSH_CONNECTION | awk '{print $1}'):0
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

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/charles/.lmstudio/bin"
# End of LM Studio CLI section


export NOTI_WEBHOOK="https://discord.com/api/webhooks/1412624603498676308/5wXrCbZXfCUUDx96MA2Smh1CB352KchMFLNThoODvpohBQIgI9rr-TBroKxKTcJ09Akd"

if [ ! -z $(which starship) ]; then
    echo "Set starship"
    eval "$(starship init bash)"
fi

if [ ! -z $(which zoxide) ]; then
    echo "Set zoxide"
    export _ZO_ECHO=1
    eval "$(zoxide init bash --cmd cd)"
    #eval "$(zoxide init bash)"
fi
