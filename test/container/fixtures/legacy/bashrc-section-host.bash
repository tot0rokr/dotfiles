
# claude-bsp plugin wrapper
declare -p CLAUDE_PLUGIN_DIRS >/dev/null 2>&1 || CLAUDE_PLUGIN_DIRS=()
declare -p CLAUDE_SETTINGS_FILES >/dev/null 2>&1 || CLAUDE_SETTINGS_FILES=()
case " ${CLAUDE_PLUGIN_DIRS[*]} " in *" @HOME@/claude-bsp "*) ;; *) CLAUDE_PLUGIN_DIRS+=(@HOME@/claude-bsp) ;; esac
function claude() {
    local d args=()
    # Flag and value as separate elements.
    for d in "${CLAUDE_PLUGIN_DIRS[@]}"; do args+=(--plugin-dir); args+=("$d"); done
    for d in "${CLAUDE_SETTINGS_FILES[@]}"; do args+=(--settings); args+=("$d"); done
    if command -v claude-auto >/dev/null 2>&1; then
        claude-auto "${args[@]}" "$@"
    else
        command claude "${args[@]}" "$@"
    fi
}

export PATH=~/.local/usr/bin:~/.local/bin:~/.local/sbin:$PATH

# Skip fzf's interactive widgets from bell auto-triggers.
declare -F bell_skip >/dev/null && bell_skip add '__fzf_history__' 'fzf-file-widget' '__fzf_cd__' 'fzf_bash_completion' >/dev/null

#source /tools/Xilinx/Vitis/2024.2/settings64.sh
source /tools/Xilinx/2025.2.1/Vitis/settings64.sh
export PATH="$XILINX_VITIS/gnu/armr5/lin/gcc-arm-none-eabi/bin:$PATH"
export MINICOM="-c on"

run_petalinux_in_docker() {
  docker run -it --rm \
    -e LOCAL_UID=$(id -u) \
    -e LOCAL_GID=$(id -g) \
    -v "$HOME/.gitconfig:/home/builder/.gitconfig:ro" \
    -v "$PWD:$PWD" \
    -w "$PWD" \
    registry.example.invalid/petalinux \
    "$@"
}
alias petalinux-create='run_petalinux_in_docker petalinux-create'
alias petalinux-build='run_petalinux_in_docker petalinux-build'

mkdir -p /tmp/$USER/
# >>> bell-bash >>>
export BELL_BASH_THRESHOLD=5
export BELL_BASH_BACKENDS='bel,webhook'
export PATH="@HOME@/.bell-bash/bin:$PATH"
source "@HOME@/.bell-bash/bell"
declare -p CLAUDE_PLUGIN_DIRS >/dev/null 2>&1 || CLAUDE_PLUGIN_DIRS=()
case " ${CLAUDE_PLUGIN_DIRS[*]} " in *" @HOME@/.bell-bash "*) ;; *) CLAUDE_PLUGIN_DIRS+=(@HOME@/.bell-bash) ;; esac
declare -p CLAUDE_SETTINGS_FILES >/dev/null 2>&1 || CLAUDE_SETTINGS_FILES=()
case " ${CLAUDE_SETTINGS_FILES[*]} " in *" @HOME@/.bell-bash/claude-settings.json "*) ;; *) CLAUDE_SETTINGS_FILES+=(@HOME@/.bell-bash/claude-settings.json) ;; esac
# <<< bell-bash <<<

# >>> noti-bash >>>
export PATH="@HOME@/.noti-bash/bin:$PATH"
declare -p CLAUDE_PLUGIN_DIRS >/dev/null 2>&1 || CLAUDE_PLUGIN_DIRS=()
case " ${CLAUDE_PLUGIN_DIRS[*]} " in *" @HOME@/.noti-bash "*) ;; *) CLAUDE_PLUGIN_DIRS+=(@HOME@/.noti-bash) ;; esac
# <<< noti-bash <<<

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
