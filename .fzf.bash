# Setup fzf
# ---------
if [[ ! "$PATH" == *$HOME/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}$HOME/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "$HOME/.fzf/shell/completion.bash" 2> /dev/null

# Key bindings
# ------------
source "$HOME/.fzf/shell/key-bindings.bash"

# Print a command that runs `fd ARGS...` in depth bands: 1-2, 3-4, 5-8, 9+.
# fd walks depth-first, so one big subtree can hold back the files right under
# $PWD until it is done; banding lists the shallow ones first. Each band
# re-reads the directories above it, which costs little next to the deep ones.
# Junk directories are skipped by fd's global ignore file, ~/.config/fd/ignore.
__fzf_fd_by_depth() {
  local args lo=1 hi cmd=
  args=$(printf ' %q' "$@")
  for hi in 2 4 8; do
    cmd+="fd --min-depth $lo --max-depth $hi$args; "
    lo=$((hi + 1))
  done
  printf '%s\n' "${cmd}fd --min-depth $lo$args"
}

export FZF_DEFAULT_COMMAND=$(__fzf_fd_by_depth --type file --follow --hidden --exclude .git)
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# Without this, Alt-C uses fzf's own walker, which reads no ignore files.
export FZF_ALT_C_COMMAND=$(__fzf_fd_by_depth --type d --follow --hidden --exclude .git)
export FZF_COMPLETION_TRIGGER='++'
export FZF_DEFAULT_OPTS='--height 50% --border'
export FZF_COMPLETION_OPTS='--border --info=inline'


# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  eval "$(__fzf_fd_by_depth --hidden --follow --exclude .git . "$1")"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  eval "$(__fzf_fd_by_depth --type d --hidden --follow --exclude .git . "$1")"
}

# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'tree -C {} | head -200'   "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview 'bat -n --color=always {}' "$@" ;;
  esac
}

# usage: _fzf_setup_completion path|dir|var|alias|host COMMANDS...
_fzf_setup_completion path ag git kubectl
_fzf_setup_completion dir tree

[ ! -f ~/.fzf-git.sh ] && curl -o ~/.fzf-git.sh https://raw.githubusercontent.com/junegunn/fzf-git.sh/main/fzf-git.sh
source ~/.fzf-git.sh
