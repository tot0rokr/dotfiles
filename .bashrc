# ~/.bashrc - shell entry point
# Portable, shared config lives in ~/.bashrc.common (tracked in dotfiles).
# Add this machine's own settings and secrets directly below.

# Non-interactive shells stop at the guard below, and `ssh host 'tmux attach'`
# is one. Put only the user-local tmux on PATH (not all of ~/.local/bin) so it
# wins over an older distro tmux there too.
if [ -x "$HOME/.local/opt/tmux/bin/tmux" ]; then
    case ":$PATH:" in
        *":$HOME/.local/opt/tmux/bin:"*) ;;
        *) export PATH="$HOME/.local/opt/tmux/bin:$PATH" ;;
    esac
fi

# If not running interactively, do not do anything.
case $- in
    *i*) ;;
      *) return ;;
esac

# Shared, dotfiles-tracked configuration.
if [ -f "$HOME/.bashrc.common" ]; then
    . "$HOME/.bashrc.common"
fi

# ============================================================
# Machine-specific settings below (edit per host)
# ============================================================
