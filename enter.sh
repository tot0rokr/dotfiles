#!/usr/bin/env bash
# enter.sh - use these dotfiles as a home without touching an account's config.
#
# Two modes:
#   1. This checkout AS the home (no copy). $HOME is pointed at the checkout and
#      an interactive shell is exec'd in place -- ideal for `ssh host -t`. The
#      account-local entry files (.bashrc, .profile, .config/git/config,
#      .config/tmux/tmux.conf) are created inside the checkout, untracked.
#      Reversible: `rm -rf` the checkout and the account is untouched.
#   2. A SPECIFIC directory as the home. Pass a directory; if dotfiles is not
#      installed there yet, enter offers to run `dotfiles install` for it
#      (interactive, with its usual checks), then drops you into a SUBSHELL
#      rooted there ($HOME=DIR). `exit` returns to your original shell.
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

# This script's own directory is the portable checkout. Physical, so it
# compares equal to TARGET however either was reached.
MYHOME="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES="$MYHOME/bin/dotfiles"

usage() {
    cat <<'EOF'
Usage: enter.sh [DIR] [tmux]

  (no args)   Use this checkout as $HOME and exec an interactive bash.
  tmux        Same, but start tmux with this config.
  DIR         Use DIR as $HOME in a subshell (exit returns). If dotfiles is
              not installed there yet, offers to run `dotfiles install` first.
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
if [[ -d "$TARGET" ]]; then
    TARGET="$(cd -P "$TARGET" && pwd -P)"
fi

# Another directory without an install yet: offer `dotfiles install` for it.
# The checkout itself never gets links; it is set up by _portable-entries below.
if [[ "$TARGET" != "$MYHOME" && ! -f "$TARGET/.local/state/dotfiles/manifest.tsv" ]]; then
    printf '%s has no dotfiles install yet. Run dotfiles install there? [y/N] ' "$TARGET" >&2
    read -r reply || reply=""
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "aborted; nothing entered." >&2; exit 1 ;;
    esac
    mkdir -p "$TARGET"
    TARGET="$(cd -P "$TARGET" && pwd -P)"
    # Run from inside another portable shell, the inherited marker would make
    # install refuse a target that is not a checkout.
    env -u DOTFILES_PORTABLE \
        HOME="$TARGET" \
        XDG_CONFIG_HOME="$TARGET/.config" \
        XDG_DATA_HOME="$TARGET/.local/share" \
        XDG_STATE_HOME="$TARGET/.local/state" \
        XDG_CACHE_HOME="$TARGET/.cache" \
        "$DOTFILES" install
fi

# Files from the old layout that the new one cannot override (not fixed here).
if [[ -e "$TARGET/.gitconfig" ]]; then
    echo "warning: $TARGET/.gitconfig is from the old layout; git reads it instead of .config/git/config. Move it away." >&2
fi
if [[ -e "$TARGET/.tmux.conf" ]]; then
    echo "warning: $TARGET/.tmux.conf is from the old layout; tmux loads it too. Move it away." >&2
fi
if grep -qs 'bashrc\.common' "$TARGET/.bashrc"; then
    echo "warning: $TARGET/.bashrc still sources .bashrc.common from the old layout." >&2
fi

# Redirect every "where is home?" lookup at TARGET. HOME drives ~, bash startup
# files, git --global, ssh, vim, fzf, ... ; the XDG_* vars keep tool state and
# caches inside TARGET too, so the host account's home stays untouched.
export HOME="$TARGET"
export XDG_CONFIG_HOME="$TARGET/.config"
export XDG_DATA_HOME="$TARGET/.local/share"
export XDG_STATE_HOME="$TARGET/.local/state"
export XDG_CACHE_HOME="$TARGET/.cache"
export DOTFILES_PORTABLE="$TARGET"
# Tool locations of the outer account; env.bash re-derives them from HOME/XDG_*.
unset CARGO_HOME RUSTUP_HOME FNM_DIR FNM_MULTISHELL_PATH npm_config_cache \
    NOTI_CONFIG NOTI_PRESET INPUTRC STARSHIP_CONFIG LOCAL_BIN_PATH \
    LOCAL_OPT_PATH LOCAL_SRC_PATH LOCAL_STATE_PATH NOTI_WEBHOOK

cd "$TARGET"

# Entering the checkout itself -> exec (replace this process; right for SSH).
# Entering some other directory -> run as a child so `exit` returns to the caller.
run=()
if [[ "$TARGET" == "$MYHOME" ]]; then
    run=(exec)
    # The checkout has no .local/bin/dotfiles, so `dotfiles` would find the
    # outer account's CLI and act on its repo. env.bash keeps this entry ahead
    # of the outer PATH.
    export PATH="$MYHOME/bin:$PATH"
    "$DOTFILES" _portable-entries
fi

case "$MODE" in
    tmux)
        # Dedicated socket: never attach to the account's existing tmux server,
        # whose shells would inherit the original $HOME instead of ours.
        # Attach to whatever's already running on this socket; if the server is
        # dead, spawn a fresh unnamed session (same semantics as the classic
        # `tmux attach || tmux new-session`).
        L="portable-$(basename "$TARGET")"
        F="$XDG_CONFIG_HOME/tmux/tmux.conf"
        TMUX_BIN=tmux
        if [[ -x "$TARGET/.local/opt/tmux/bin/tmux" ]]; then
            TMUX_BIN="$TARGET/.local/opt/tmux/bin/tmux"
        fi
        v="$("$TMUX_BIN" -V 2>/dev/null || true)"
        if [[ $v =~ ([0-9]+)\.([0-9]+) ]] \
            && (( BASH_REMATCH[1] < 3 || (BASH_REMATCH[1] == 3 && BASH_REMATCH[2] < 2) )); then
            echo "warning: $v is older than 3.2 and cannot load $F; run 'dotfiles bootstrap user' inside." >&2
        fi
        if "$TMUX_BIN" -L "$L" has-session 2>/dev/null; then
            "${run[@]}" "$TMUX_BIN" -L "$L" attach
        else
            "${run[@]}" "$TMUX_BIN" -L "$L" -f "$F" new-session
        fi
        ;;
    bash)
        # --rcfile is belt-and-suspenders: HOME already points here, but this
        # guarantees the right .bashrc even if something else resolves ~ oddly.
        "${run[@]}" bash --rcfile "$TARGET/.bashrc" -i
        ;;
esac
