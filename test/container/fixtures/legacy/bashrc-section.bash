# >>> bell-bash >>>
export BELL_BASH_THRESHOLD=30
export BELL_BASH_BACKENDS='bel,notify-send,webhook'
export BELL_BASH_HOME="$HOME/.bell-bash"
export PATH="$HOME/.bell-bash/bin:$PATH"
source "$HOME/.bell-bash/bell"
declare -p CLAUDE_PLUGIN_DIRS >/dev/null 2>&1 || CLAUDE_PLUGIN_DIRS=()
case " ${CLAUDE_PLUGIN_DIRS[*]} " in *" $HOME/.bell-bash "*) ;; *) CLAUDE_PLUGIN_DIRS+=($HOME/.bell-bash) ;; esac
declare -p CLAUDE_SETTINGS_FILES >/dev/null 2>&1 || CLAUDE_SETTINGS_FILES=()
case " ${CLAUDE_SETTINGS_FILES[*]} " in *" $HOME/.bell-bash/claude-settings.json "*) ;; *) CLAUDE_SETTINGS_FILES+=($HOME/.bell-bash/claude-settings.json) ;; esac
# <<< bell-bash <<<
# >>> noti-bash >>>
export PATH="$HOME/.noti-bash/bin:$PATH"
declare -p CLAUDE_PLUGIN_DIRS >/dev/null 2>&1 || CLAUDE_PLUGIN_DIRS=()
case " ${CLAUDE_PLUGIN_DIRS[*]} " in *" $HOME/.noti-bash "*) ;; *) CLAUDE_PLUGIN_DIRS+=($HOME/.noti-bash) ;; esac
export NOTI_WEBHOOK="https://hooks.example.invalid/t-s2"
# <<< noti-bash <<<
bell_skip add '__fzf_history__' 'fzf-file-widget' >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
. "$HOME/.cargo/env"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# claude-account-switcher: rotate accounts on usage limits
command -v claude-auto >/dev/null 2>&1 && alias claude="claude-auto"
# >>> modern grep/find (rg/fd) >>>
[ -f "$HOME/.config/shell/modern-grep-find.bash" ] && source "$HOME/.config/shell/modern-grep-find.bash"
# <<< modern grep/find <<<
claude() {
    command claude --plugin-dir "$HOME/claude-bsp" "$@"
}
if [ -f /tools/Xilinx/Vivado/2023.2/settings64.sh ]; then
    . /tools/Xilinx/Vivado/2023.2/settings64.sh
fi
alias minicom='minicom -w -c on'
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias petalinux-run='docker run --rm -v "$HOME/.gitconfig:/home/builder/.gitconfig:ro" petalinux'
export FZF_BASE="$HOME/.fzf"
export PATH="/opt/t-tools/bin:$PATH"
HISTFILESIZE=2000

# t-note-kept: explains the next two lines
bell_skip add '__fzf_history__' >/dev/null
export T_NOTE_KEPT=1

# t-note-dropped: rust toolchain
export PATH="$HOME/.cargo/bin:$PATH"
. "$HOME/.cargo/env"
