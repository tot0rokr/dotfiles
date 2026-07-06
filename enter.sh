#!/usr/bin/env bash
# enter.sh - use these dotfiles as a home without touching an account's config.
#
# Two modes:
#   1. This checkout AS the home (no copy). $HOME is pointed at the checkout and
#      an interactive shell is exec'd in place -- ideal for `ssh host -t`.
#      Reversible: `rm -rf` the checkout and the account is untouched.
#   2. A SPECIFIC directory as the home. Pass a directory; if it isn't set up
#      yet, enter offers to populate it via install.sh, then drops you into a
#      SUBSHELL rooted there ($HOME=DIR). `exit` returns to your original shell.
#
# Because bash's ~, startup files, git --global, ssh, vim, fzf, starship,
# zoxide, ... all resolve "home" via $HOME (+ XDG_*), you get this environment
# as if you had logged in with it. The account's own ~/.bashrc etc. stay unread.
#
# Setup on a target host:
#   git clone <repo> ~/.myhome        # the checkout == a portable home
#
# Usage:
#   ~/.myhome/enter.sh                # interactive bash in the checkout env
#   ~/.myhome/enter.sh tmux           # go straight into tmux with this config
#   ~/.myhome/enter.sh ~/box          # make ~/box the home (offers to install)
#   ~/.myhome/enter.sh ~/box tmux     # ... and start tmux there
#   ssh host -t '~/.myhome/enter.sh'  # SSH in and land in the env immediately
set -euo pipefail

# This script's own directory is the portable checkout (holds .bashrc,
# .gitconfig, .tmux.conf, install.sh, ...). Resolving it keeps it relocatable.
MYHOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$MYHOME/install.sh"

usage() {
    cat <<'EOF'
Usage: enter.sh [DIR] [tmux]

  (no args)   Use this checkout as $HOME and exec an interactive bash.
  tmux        Same, but start tmux with this config.
  DIR         Use DIR as $HOME in a subshell (exit returns). If DIR is not set
              up yet, offers to populate it with install.sh first.
  DIR tmux    Use DIR as $HOME and start tmux there.
  -h, --help  Show this help.
EOF
}

# --- parse args: [DIR] and/or [tmux], in any order ---------------------------
TARGET="$MYHOME"
MODE="bash"
for arg in "$@"; do
    case "$arg" in
        tmux)      MODE="tmux" ;;
        -h|--help) usage; exit 0 ;;
        -*)        echo "unknown option: $arg" >&2; usage >&2; exit 2 ;;
        *)         TARGET="$arg" ;;
    esac
done

# Absolutise TARGET relative to the invocation CWD (~ is expanded by the caller).
case "$TARGET" in
    /*) ;;
    *)  TARGET="$PWD/$TARGET" ;;
esac

# Targeting a not-yet-set-up directory? Offer to install into it first (collab
# with install.sh). The checkout itself is always already set up, so it skips.
if [[ "$TARGET" != "$MYHOME" && ! -f "$TARGET/.bashrc" ]]; then
    printf '%s is not set up as a home yet. Install dotfiles there? [y/N] ' "$TARGET" >&2
    read -r reply || reply=""
    case "$reply" in
        [yY]|[yY][eE][sS]) "$INSTALL" --dest "$TARGET" ;;
        *) echo "aborted; nothing entered." >&2; exit 1 ;;
    esac
fi

# Canonicalise now that the directory is guaranteed to exist.
TARGET="$(cd "$TARGET" && pwd)"

# Redirect every "where is home?" lookup at TARGET. HOME drives ~, bash startup
# files, git --global, ssh, vim, fzf, ... ; the XDG_* vars keep tool state and
# caches inside TARGET too, so the host account's home stays untouched.
export HOME="$TARGET"
export XDG_CONFIG_HOME="$TARGET/.config"
export XDG_DATA_HOME="$TARGET/.local/share"
export XDG_STATE_HOME="$TARGET/.local/state"
export XDG_CACHE_HOME="$TARGET/.cache"
export DOTFILES_PORTABLE="$TARGET"

cd "$TARGET"

# Entering the checkout itself -> exec (replace this process; right for SSH).
# Entering some other directory -> run as a child so `exit` returns to the caller.
run=()
if [[ "$TARGET" == "$MYHOME" ]]; then run=(exec); fi

case "$MODE" in
    tmux)
        # Dedicated socket: never attach to the account's existing tmux server,
        # whose shells would inherit the original $HOME instead of ours.
        "${run[@]}" tmux -L "portable-$(basename "$TARGET")" -f "$TARGET/.tmux.conf"
        ;;
    bash)
        # --rcfile is belt-and-suspenders: HOME already points here, but this
        # guarantees the right .bashrc even if something else resolves ~ oddly.
        "${run[@]}" bash --rcfile "$TARGET/.bashrc" -i
        ;;
esac
