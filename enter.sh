#!/usr/bin/env bash
# enter.sh - use these dotfiles on a host without touching that account's config.
#
# It does NOT copy anything into the account (that's install.sh's job). Instead
# it points $HOME (and the XDG dirs) at this checkout, then execs an interactive
# shell. Because bash's ~, startup files, git --global, ssh, vim, fzf, starship,
# zoxide, ... all resolve "home" via $HOME, you get this environment as if you
# had logged in with it. The account's own ~/.bashrc etc. are never read.
#
# Setup on the target host:
#   git clone <repo> ~/.myhome        # this checkout == the portable home
#
# Usage:
#   ~/.myhome/enter.sh                # interactive bash in the portable env
#   ~/.myhome/enter.sh tmux           # go straight into tmux with this config
#   ssh host -t '~/.myhome/enter.sh'  # SSH in and land in the env immediately
#
# Fully reversible: `rm -rf ~/.myhome` leaves the account exactly as it was.
set -euo pipefail

# This script's own directory is the portable home (holds .bashrc, .gitconfig,
# .tmux.conf, ...). Resolving it here keeps the checkout relocatable.
MYHOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Redirect every "where is home?" lookup at MYHOME. HOME drives ~, bash startup
# files, git --global, ssh, vim, fzf, ... ; the XDG_* vars keep tool state and
# caches inside MYHOME too, so the host account's home stays untouched.
export HOME="$MYHOME"
export XDG_CONFIG_HOME="$MYHOME/.config"
export XDG_DATA_HOME="$MYHOME/.local/share"
export XDG_STATE_HOME="$MYHOME/.local/state"
export XDG_CACHE_HOME="$MYHOME/.cache"

# Marker so scripts/prompts can tell they're running inside the portable env.
export DOTFILES_PORTABLE="$MYHOME"

cd "$MYHOME"

case "${1:-}" in
    tmux)
        # Dedicated socket: never attach to the account's existing tmux server,
        # whose shells would inherit the original $HOME instead of ours.
        exec tmux -L "portable-$(basename "$MYHOME")" -f "$MYHOME/.tmux.conf"
        ;;
    "")
        # --rcfile is belt-and-suspenders: HOME already points here, but this
        # guarantees the right .bashrc even if something else resolves ~ oddly.
        exec bash --rcfile "$MYHOME/.bashrc" -i
        ;;
    *)
        echo "usage: ${BASH_SOURCE[0]##*/} [tmux]" >&2
        exit 2
        ;;
esac
