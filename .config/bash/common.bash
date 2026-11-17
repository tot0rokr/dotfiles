# ~/.config/bash/common.bash - shared interactive shell configuration (tracked in dotfiles)
# Portable, machine-agnostic, and secret-free. Sourced by the managed block of
# ~/.bashrc, after env.bash. Machine-specific settings belong in the local zones
# of ~/.bashrc, secrets in ~/.config/secrets.env (NOT tracked here).
# Tool install: `dotfiles bootstrap user` (no root) / `system` (sudo apt) /
# `agents` (Claude/Codex/OpenCode/Gemini harness); the bootstrap_* functions
# below wrap it.

# Absolute, because the bootstrap wrappers below may run from any directory.
__dotfiles_bash_dir=${BASH_SOURCE[0]%/*}
[ "$__dotfiles_bash_dir" = "${BASH_SOURCE[0]}" ] && __dotfiles_bash_dir=.
case $__dotfiles_bash_dir in
    /*) ;;
    *) __dotfiles_bash_dir=$PWD/$__dotfiles_bash_dir ;;
esac

# History settings. HISTFILE comes first: assigning HISTFILESIZE truncates
# whichever file HISTFILE names at that moment. bash silently stops saving
# history when the file's directory is missing.
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/bash/history
[ -d "${HISTFILE%/*}" ] || mkdir -p "${HISTFILE%/*}"
HISTSIZE=10000
HISTFILESIZE=100000

# Update terminal size after each command.
shopt -s checkwinsize

# User-local paths.
export LOCAL_BIN_PATH="$HOME/.local/bin"
export LOCAL_OPT_PATH="$HOME/.local/opt"
export LOCAL_SRC_PATH="$HOME/.local/src"
export LOCAL_STATE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$LOCAL_BIN_PATH" "$LOCAL_OPT_PATH" "$LOCAL_SRC_PATH" "$LOCAL_STATE_PATH"

__path_prepend() {
    [ -n "$1" ] || return 0
    [ -d "$1" ] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# Drop repeated PATH entries, keeping the first one, which is the one command
# lookup already hits, so no command resolves differently. Machine-local rc
# lines (~/.bashrc, tool installers, vendor settings scripts) prepend without
# checking, so PATH grows with every nested shell. Runs once, from the first
# prompt, by which time every startup file has made its changes. It then
# turns itself into a no-op rather than leaving PROMPT_COMMAND: starship and
# bell-bash move that string into their own variables.
__path_dedupe() {
    local rest=$PATH: dir
    local -a keep=()
    local -A seen=()
    while [[ -n $rest ]]; do
        dir=${rest%%:*}
        rest=${rest#*:}
        # Prefix the key: an empty entry (the current directory) is a valid
        # PATH element but not a valid associative-array subscript.
        [[ -n ${seen[x$dir]-} ]] && continue
        seen[x$dir]=1
        keep+=("$dir")
    done
    local IFS=:
    [[ ${keep[*]} == "$PATH" ]] || PATH=${keep[*]}
    __path_dedupe() { :; }
}

# Move ~/.local/opt/fzf/bin to the front, ahead of a host fzf (apt, Homebrew):
# the shell bindings in ~/.local/opt/fzf/shell and the Vim plugin in
# ~/.local/opt/fzf expect the binary from the same checkout. Unlike
# __path_prepend, this also moves an entry already on PATH further back, e.g.
# one a parent shell got from ~/.config/fzf/fzf.bash appending it.
__path_fzf_first() {
    local dir="$HOME/.local/opt/fzf/bin" rest=":$PATH:"
    [ -d "$dir" ] || return 0
    while [[ $rest == *":$dir:"* ]]; do
        rest=${rest/":$dir:"/:}
    done
    rest=${rest#:}
    rest=${rest%:}
    PATH="$dir${rest:+:$rest}"
}

__path_fzf_first
__path_prepend "$HOME/.lmstudio/bin"
export PATH

# Make less more friendly for non-text input files.
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Chroot name for the prompt.
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Prompt color support.
case "$TERM" in
    xterm-kitty|xterm-color|*-256color) color_prompt=yes ;;
esac

if [ -n "${force_color_prompt:-}" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

# Git prompt support from the copy next to this file.
. "$__dotfiles_bash_dir/git-prompt.sh"

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    if declare -F __git_ps1 >/dev/null 2>&1; then
        PS1=$PS1'\[\033[01;35m\]$(__git_ps1 " (%s)")\[\033[00m\] '
    fi
else
    if declare -F __git_ps1 >/dev/null 2>&1; then
        PS1='${debian_chroot:+($debian_chroot)}\u:\W\$$(__git_ps1 " (%s)") '
    else
        PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
    fi
fi

. "$__dotfiles_bash_dir/git-completion.bash"

unset color_prompt force_color_prompt

# Set xterm title.
case "$TERM" in
    xterm*|rxvt*) PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1" ;;
esac

# Color aliases.
if [ -x /usr/bin/dircolors ]; then
    test -r "$HOME/.dircolors" && eval "$(dircolors -b "$HOME/.dircolors")" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Tab completion behavior.
bind 'TAB:menu-complete'
bind '"\e[Z":menu-complete-backward'

# Claude Code plugin dirs and settings files, passed as --plugin-dir/--settings
# by the claude() wrapper below. Values set before this file runs are kept, and
# appends skip duplicates, so re-sourcing ~/.bashrc does not repeat arguments.
declare -p CLAUDE_PLUGIN_DIRS >/dev/null 2>&1 || CLAUDE_PLUGIN_DIRS=()
declare -p CLAUDE_SETTINGS_FILES >/dev/null 2>&1 || CLAUDE_SETTINGS_FILES=()

__claude_arg_add() {
    local -n __claude_arr=$1
    local v
    for v in "${__claude_arr[@]}"; do
        [ "$v" = "$2" ] && return 0
    done
    __claude_arr+=("$2")
}

# noti-bash: Discord/Slack webhook CLI, cloned by `dotfiles bootstrap user`. Its
# executable comes from the clone (no longer vendored in this repo); put its
# bin on PATH here, and the clone in front of Claude as a plugin (its skill).
# Both no-op when the clone isn't present.
__path_prepend "$LOCAL_OPT_PATH/noti-bash/bin"
if [ -d "$LOCAL_OPT_PATH/noti-bash" ]; then
    __claude_arg_add CLAUDE_PLUGIN_DIRS "$LOCAL_OPT_PATH/noti-bash"
fi

# Run claude with the plugin dirs and settings files above, through claude-auto
# (the account switcher) when it is installed. A claude() defined later in
# ~/.bashrc replaces this one; an `alias claude=...` would bypass it and drop
# those arguments.
function claude() {
    local d args=()
    for d in "${CLAUDE_PLUGIN_DIRS[@]}"; do args+=(--plugin-dir); args+=("$d"); done
    for d in "${CLAUDE_SETTINGS_FILES[@]}"; do args+=(--settings); args+=("$d"); done
    if command -v claude-auto >/dev/null 2>&1; then
        claude-auto "${args[@]}" "$@"
    else
        command claude "${args[@]}" "$@"
    fi
}

# Optional secret loading. Keep the actual webhook outside .bashrc.
if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/noti/webhook" ]; then
    export NOTI_WEBHOOK="$(sed -n '1p' "${XDG_CONFIG_HOME:-$HOME/.config}/noti/webhook")"
fi

# Load user secrets (tokens, API keys). File must be chmod 600.
if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/secrets.env" ]; then
    . "${XDG_CONFIG_HOME:-$HOME/.config}/secrets.env"
fi

# The installers live in the dotfiles CLI; these keep the old function names.
# The repo's own CLI comes first, so a portable checkout uses its copy: `..`
# resolves physically, through the ~/.config/bash link, into the repo.
if [ -x "$__dotfiles_bash_dir/../../bin/dotfiles" ]; then
    __dotfiles_bin=$__dotfiles_bash_dir/../../bin/dotfiles
else
    __dotfiles_bin=dotfiles
fi
bootstrap_system_tools() { "$__dotfiles_bin" bootstrap system "$@"; }
bootstrap_user_tools() { "$__dotfiles_bin" bootstrap user "$@"; }
bootstrap_agents() { "$__dotfiles_bin" bootstrap agents "$@"; }

# Safe X11 DISPLAY setup for SSH, even inside tmux.
if [[ -n "${SSH_CONNECTION:-}" ]]; then
    export DISPLAY=$(echo "$SSH_CONNECTION" | awk '{print $1}'):0
fi

# User aliases.
. "$__dotfiles_bash_dir/aliases.bash"

# Programmable completion from existing system files only, loaded once: a
# re-sourced ~/.bashrc or the distro /etc/bash.bashrc may have loaded it.
if [ -z "${BASH_COMPLETION_VERSINFO:-}" ] && ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

. "$__dotfiles_bash_dir/../fzf/fzf.bash"

# fzf-tab-completion: TAB opens completion candidates in fzf. Must load after
# bash-completion; overrides the plain `TAB:menu-complete` bind above, which
# stays as the fallback when fzf or the clone is missing.
if [ -f "$HOME/.local/opt/fzf-tab-completion/bash/fzf-bash-completion.sh" ] && command -v fzf >/dev/null 2>&1; then
    . "$HOME/.local/opt/fzf-tab-completion/bash/fzf-bash-completion.sh"
    bind -x '"\t": fzf_bash_completion'
fi

# The prompt hooks below are installed once per shell, so re-sourcing
# ~/.bashrc leaves them as they are. starship and bell-bash move PROMPT_COMMAND
# into their own variables, where neither a second append nor their own
# duplicate checks would find the first copy, and the two would then call each
# other at the next prompt until bash crashes.
__prompt_has_hook() {
    case "${PROMPT_COMMAND[*]-};${STARSHIP_PROMPT_COMMAND-};${__bell_bash_prev_pc-}" in
        *"$1"*) return 0 ;;
    esac
    return 1
}

__prompt_has_hook 'history -a; history -n' ||
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a; history -n; __path_dedupe"

# Prompt caches stay on local disk so each host of the shared NFS home keeps
# its own. Prefer /run/user/<uid>: logind creates it as ours, whereas
# /tmp/$USER turns root-owned when a root process (a docker bind mount) makes
# it first, and every cache write then fails.
if [[ -n $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR && -w $XDG_RUNTIME_DIR ]]; then
    __prompt_cache_root=$XDG_RUNTIME_DIR/prompt-cache
else
    __prompt_cache_root=${TMPDIR:-/tmp}/$USER
fi

# starship's git_status walks the whole work tree, 0.2-0.6s per prompt on the
# NFS home. Run it in the background instead and show the last finished
# result through env_var.PROMPT_GIT_STATUS (starship.toml), so the prompt
# never waits for git; the status may lag one prompt behind.
__prompt_git_cache="$__prompt_cache_root/prompt-git-status"

__prompt_git_status() {
    local root=$PWD cache pid
    while [[ -n $root && ! -e $root/.git ]]; do root=${root%/*}; done
    if [[ -z $root ]]; then
        unset PROMPT_GIT_STATUS
        return
    fi
    cache=$__prompt_git_cache/${root//\//%}

    PROMPT_GIT_STATUS=
    [[ -r $cache ]] && IFS= read -r PROMPT_GIT_STATUS <"$cache"
    if [[ -n $PROMPT_GIT_STATUS ]]; then
        export PROMPT_GIT_STATUS
    else
        unset PROMPT_GIT_STATUS
    fi

    # One refresh per repo at a time; a dead pid (killed shell) frees the slot.
    if [[ -r $cache.pid ]] && read -r pid <"$cache.pid" && kill -0 "$pid" 2>/dev/null; then
        return
    fi
    # Double fork keeps the job out of this shell's job table (no [1] Done).
    ( {
        # Fix the pid now: a redirect on an external command expands
        # $BASHPID in the forked child.
        local tmp=$cache.$BASHPID
        mkdir -p "$__prompt_git_cache" || exit
        echo "$BASHPID" >"$cache.pid"
        # Unset STARSHIP_SHELL so `$` stays unescaped; the env_var module
        # escapes the value when it renders the real prompt.
        builtin cd "$root" &&
            STARSHIP_SHELL= starship module git_status >"$tmp" &&
            command mv -f "$tmp" "$cache"
        command rm -f "$tmp" "$cache.pid"
    } </dev/null >/dev/null 2>&1 & )
}

# starship's os module runs `lsb_release -a` (a shell script that forks ~7
# processes, ~20ms) on every prompt just to pick an icon. Resolve it once per
# host and config: cache the plain symbol under $__prompt_cache_root and show
# it through env_var.PROMPT_OS (starship.toml). Editing starship.toml makes the
# cache stale. An unwritable cache dir falls back to resolving it uncached.
__prompt_os_init() {
    local cfg=${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}
    local cache=$__prompt_cache_root/prompt-os
    if [[ ! -e $cache || $cfg -nt $cache ]] &&
        mkdir -p "${cache%/*}" 2>/dev/null && [[ -w ${cache%/*} ]]; then
        STARSHIP_SHELL= starship module os 2>/dev/null >"$cache.$$" &&
            command mv -f "$cache.$$" "$cache"
        command rm -f "$cache.$$"
    fi
    PROMPT_OS=
    if [[ -r $cache ]]; then
        IFS= read -r PROMPT_OS <"$cache"
    else
        PROMPT_OS=$(STARSHIP_SHELL= starship module os 2>/dev/null)
    fi
    if [[ -n $PROMPT_OS ]]; then
        export PROMPT_OS
    else
        unset PROMPT_OS
    fi
}

# Prompt themes. starship reads its palette only from the config file, so the
# chosen palette's name is kept in a state file that every host of the NFS
# home shares. Each host renders starship.toml with that palette into its
# local prompt cache and points STARSHIP_CONFIG there. A shell reads the
# choice when it starts and when `prompt-theme` changes it; shells of the same
# host that already use the rendered copy follow at their next prompt.
__prompt_theme_src=${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml
__prompt_theme_state=${XDG_STATE_HOME:-$HOME/.local/state}/starship/palette
__prompt_theme_copy=$__prompt_cache_root/starship.toml

# Only the palettes that define the segment keys can color this prompt.
__prompt_theme_names() {
    awk '/^\[/ { name = "" }
        /^\[palettes\./ { name = substr($0, 11, length($0) - 11) }
        /^user_bg[ =]/ && name != "" { print name }' "$__prompt_theme_src"
}

__prompt_theme_sync() {
    local name
    export STARSHIP_CONFIG=$__prompt_theme_src
    [[ -r $__prompt_theme_state ]] || return 0
    if [[ $__prompt_theme_state -nt $__prompt_theme_copy || $__prompt_theme_src -nt $__prompt_theme_copy ]]; then
        IFS= read -r name <"$__prompt_theme_state"
        if ! grep -qxF "[palettes.$name]" "$__prompt_theme_src"; then
            printf 'prompt-theme: no palette "%s" in %s, using its default\n' "$name" "$__prompt_theme_src" >&2
            return 1
        fi
        if ! { mkdir -p "${__prompt_theme_copy%/*}" &&
            sed "s/^palette = .*/palette = '$name'/" "$__prompt_theme_src" >"$__prompt_theme_copy.$$" &&
            command mv -f "$__prompt_theme_copy.$$" "$__prompt_theme_copy"; } 2>/dev/null; then
            command rm -f "$__prompt_theme_copy.$$"
            return 1
        fi
    fi
    export STARSHIP_CONFIG=$__prompt_theme_copy
}

# prompt-theme          list the palettes; * marks the one this shell uses
# prompt-theme NAME     switch every shell to NAME
# prompt-theme next     switch to the palette after the current one
prompt-theme() {
    local names cur name i found=
    mapfile -t names < <(__prompt_theme_names)
    cur=$(sed -n "s/^palette = '\(.*\)'$/\1/p" "$STARSHIP_CONFIG")
    case ${1-} in
        '')
            for name in "${names[@]}"; do
                if [[ $name == "$cur" ]]; then printf '* %s\n' "$name"; else printf '  %s\n' "$name"; fi
            done
            return
            ;;
        next)
            name=${names[0]-}
            for i in "${!names[@]}"; do
                [[ ${names[i]} == "$cur" ]] && name=${names[(i + 1) % ${#names[@]}]}
            done
            ;;
        *) name=$1 ;;
    esac
    for i in "${names[@]}"; do
        [[ $i == "$name" ]] && found=1
    done
    if [[ -z $found ]]; then
        printf 'prompt-theme: no palette "%s"; run prompt-theme to list them\n' "$name" >&2
        return 1
    fi
    mkdir -p "${__prompt_theme_state%/*}" &&
        printf '%s\n' "$name" >"$__prompt_theme_state" &&
        __prompt_theme_sync
}

if command -v starship >/dev/null 2>&1; then
    # On a cold NFS cache the directory scan for the language modules outlasts
    # scan_timeout, and starship warns above the prompt each time. The scan
    # only ends early (the modules may skip one prompt), so keep errors only.
    export STARSHIP_LOG=error
    declare -F starship_precmd >/dev/null || eval "$(starship init bash)"
    starship_precmd_user_func=__prompt_git_status
    __prompt_theme_sync
    __prompt_os_init
fi

if command -v zoxide >/dev/null 2>&1; then
    export _ZO_ECHO=1
    declare -F __zoxide_hook >/dev/null || eval "$(zoxide init bash)"
fi

# >>> modern grep/find (rg/fd) >>>
# Translate common grep/find invocations to rg/fd; fall back to the real tool
# for anything unrecognized. Interactive-only (the file self-guards on $-).
# Per-call bypass: `command grep ...` / `command find ...`.
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/shell/modern-grep-find.bash" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/modern-grep-find.bash"
# <<< modern grep/find <<<

# fnm: node version switching. env.bash puts the default version on PATH for
# every shell; `fnm env` puts this shell's own version dir in front of it.
# Its `cd` alias is dropped: zoxide's `z` and pushd/popd change directory
# through the builtin and never reach it. A prompt hook switches on any PWD
# change instead, before starship renders the prompt; the first prompt also
# covers the directory the shell started in. Kept after the starship block,
# whose precmd hook it extends.
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
    unalias cd 2>/dev/null
    __fnm_last_pwd=
    __fnm_pwd_hook() {
        local status=$?
        if [ "$PWD" != "$__fnm_last_pwd" ]; then
            __fnm_last_pwd=$PWD
            __fnm_use_if_file_found
        fi
        return $status
    }
    if declare -F starship_precmd >/dev/null 2>&1; then
        __dotfiles_precmd() {
            __fnm_pwd_hook
            __prompt_git_status
        }
        starship_precmd_user_func=__dotfiles_precmd
    elif ! __prompt_has_hook __fnm_pwd_hook; then
        PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__fnm_pwd_hook"
    fi
fi

# bell-bash: long-running command notifications (cloned by `dotfiles bootstrap
# user` into $LOCAL_OPT_PATH). Wired here rather than by the clone's own
# installer so the tracked dotfiles stay the single owner of the shell env; the
# guard makes it a no-op on hosts where it isn't installed. Override
# BELL_BASH_BACKENDS per host in the interactive local zone of ~/.bashrc
# (e.g. add ',webhook').
# Kept last: without bash-preexec, bell wraps the PROMPT_COMMAND it finds and
# times the first command that runs after its own hook. A prompt hook
# installed after bell (starship, zoxide, fnm) would be that command.
if [ -f "$LOCAL_OPT_PATH/bell-bash/bell" ]; then
    export BELL_BASH_BACKENDS='bel,notify-send'
    __path_prepend "$LOCAL_OPT_PATH/bell-bash/bin"
    declare -F __bell_bash_prompt_command >/dev/null || . "$LOCAL_OPT_PATH/bell-bash/bell"
    # Skip fzf's interactive widgets from bell auto-triggers: Ctrl-R history
    # (__fzf_history__), Ctrl-T file (fzf-file-widget), Alt-C cd (__fzf_cd__).
    # Plain TAB completion needs no entry (bell bails when COMP_LINE is set), but
    # fzf-tab-completion's `bind -x` widget (fzf_bash_completion) does: on an
    # empty line READLINE_LINE is empty too, so bell would not skip it. Append
    # via bell_skip (not a pre-defined array — pre-defining would replace bell's
    # sensible defaults wholesale).
    if declare -F bell_skip >/dev/null 2>&1; then
        bell_skip add '__fzf_history__' 'fzf-file-widget' '__fzf_cd__' 'fzf_bash_completion' >/dev/null
    fi
    # The clone is also a Claude Code plugin (its skill); its settings file
    # carries the Stop/Notification toast hooks.
    __claude_arg_add CLAUDE_PLUGIN_DIRS "$LOCAL_OPT_PATH/bell-bash"
    if [ -f "$LOCAL_OPT_PATH/bell-bash/claude-settings.json" ]; then
        __claude_arg_add CLAUDE_SETTINGS_FILES "$LOCAL_OPT_PATH/bell-bash/claude-settings.json"
    fi
fi
